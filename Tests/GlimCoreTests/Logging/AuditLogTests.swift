import Foundation
import Testing

@testable import GlimCore

struct AuditLogTests {
    func date(_ isoText: String) throws -> Date {
        try Date(isoText, strategy: .iso8601)
    }

    func logFileNames(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
            .sorted()
    }

    @Test func appendedEventsReadBackInOrder() async throws {
        try await withTemporaryDirectory { directory in
            let now = try date("2026-09-23T10:00:00Z")
            let auditLog = AuditLog(directory: directory, now: { now })

            try await auditLog.append(.settingsChanged, summary: "first", details: ["key": "value"])
            try await auditLog.append(.settingsReset, summary: "second")

            let events = try await auditLog.readAllEvents()
            #expect(events.map(\.summary) == ["first", "second"])
            #expect(events.first?.details == ["key": "value"])
            #expect(events.first?.timestamp == now)
            #expect(events.first?.kind == .settingsChanged)
        }
    }

    @Test func filesAreNamedByUTCDay() async throws {
        try await withTemporaryDirectory { directory in
            let lateEvening = try date("2026-09-23T23:30:00Z")
            let auditLog = AuditLog(directory: directory, now: { lateEvening })

            try await auditLog.append(.settingsChanged, summary: "late")

            #expect(try logFileNames(in: directory) == ["audit-2026-09-23-001.jsonl"])
        }
    }

    @Test func eventsOlderThanTheRetentionAreDeleted() async throws {
        try await withTemporaryDirectory { directory in
            let oldDay = try date("2026-09-10T12:00:00Z")
            let today = try date("2026-09-23T12:00:00Z")
            try await AuditLog(directory: directory, now: { oldDay })
                .append(.settingsChanged, summary: "old")

            let auditLog = AuditLog(directory: directory, now: { today })
            try await auditLog.append(.settingsChanged, summary: "new")

            let summaries = try await auditLog.readAllEvents().map(\.summary)
            #expect(summaries == ["new"])
            #expect(try logFileNames(in: directory) == ["audit-2026-09-23-001.jsonl"])
        }
    }

    @Test func eventsWithinTheRetentionAreKept() async throws {
        try await withTemporaryDirectory { directory in
            let sixDaysAgo = try date("2026-09-17T12:00:00Z")
            let today = try date("2026-09-23T12:00:00Z")
            try await AuditLog(directory: directory, now: { sixDaysAgo })
                .append(.settingsChanged, summary: "recent")

            let auditLog = AuditLog(directory: directory, now: { today })
            try await auditLog.append(.settingsChanged, summary: "new")

            let summaries = try await auditLog.readAllEvents().map(\.summary)
            #expect(summaries == ["recent", "new"])
        }
    }

    @Test func fullFileRotatesToTheNextPart() async throws {
        try await withTemporaryDirectory { directory in
            let now = try date("2026-09-23T10:00:00Z")
            let tinyFiles = AuditRetention(
                maximumAge: AuditRetention.standard.maximumAge,
                maximumTotalBytes: 10_000,
                maximumBytesPerFile: 200)
            let auditLog = AuditLog(directory: directory, retention: tinyFiles, now: { now })
            let longSummary = String(repeating: "x", count: 120)

            for _ in 0..<3 {
                try await auditLog.append(.settingsChanged, summary: longSummary)
            }

            #expect(
                try logFileNames(in: directory) == [
                    "audit-2026-09-23-001.jsonl", "audit-2026-09-23-002.jsonl",
                    "audit-2026-09-23-003.jsonl",
                ])
            let eventCount = try await auditLog.readAllEvents().count
            #expect(eventCount == 3)
        }
    }

    @Test func totalSizeCapDeletesTheOldestFilesFirst() async throws {
        try await withTemporaryDirectory { directory in
            let now = try date("2026-09-23T10:00:00Z")
            let smallCap = AuditRetention(
                maximumAge: AuditRetention.standard.maximumAge,
                maximumTotalBytes: 450,
                maximumBytesPerFile: 200)
            let auditLog = AuditLog(directory: directory, retention: smallCap, now: { now })
            let longSummary = String(repeating: "x", count: 120)

            for eventNumber in 1...6 {
                try await auditLog.append(
                    .settingsChanged, summary: "\(eventNumber) \(longSummary)")
            }

            let remainingSummaries = try await auditLog.readAllEvents().map(\.summary)
            #expect(remainingSummaries.count < 6)
            #expect(remainingSummaries.last?.hasPrefix("6 ") == true)
            #expect(try logFileNames(in: directory).last == "audit-2026-09-23-006.jsonl")
        }
    }

    @Test func clearRemovesEveryEvent() async throws {
        try await withTemporaryDirectory { directory in
            let now = try date("2026-09-23T10:00:00Z")
            let auditLog = AuditLog(directory: directory, now: { now })
            try await auditLog.append(.settingsChanged, summary: "gone soon")

            try await auditLog.clear()

            let remainingEvents = try await auditLog.readAllEvents()
            #expect(remainingEvents.isEmpty)
        }
    }

    @Test func missingDirectoryReadsAsEmpty() async throws {
        try await withTemporaryDirectory { directory in
            let auditLog = AuditLog(directory: directory.appending(path: "not-created-yet"))

            let remainingEvents = try await auditLog.readAllEvents()
            #expect(remainingEvents.isEmpty)
        }
    }
}

struct AuditLogDamageTests {
    @Test func aDamagedLineIsSkippedNotFatal() async throws {
        try await withTemporaryDirectory { directory in
            let now = try Date("2026-09-23T10:00:00Z", strategy: .iso8601)
            let auditLog = AuditLog(directory: directory, now: { now })
            try await auditLog.append(.settingsChanged, summary: "before")
            let fileURL = directory.appending(path: "audit-2026-09-23-001.jsonl")
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: Data("{\"cut off by a force quit\n".utf8))
            try fileHandle.close()
            try await auditLog.append(.settingsChanged, summary: "after")

            let summaries = try await auditLog.readAllEvents().map(\.summary)

            #expect(summaries == ["before", "after"])
        }
    }
}
