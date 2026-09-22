import Foundation
import os

/// Append-only record of everything Glim decides and does, as JSON Lines on this Mac.
///
/// Files are named `audit-YYYY-MM-DD-NNN.jsonl` by UTC day and part number, so name order is
/// time order. After every append, files older than the retention age are deleted, then the
/// oldest files are deleted until the total fits the size cap.
public actor AuditLog {
    private static let logger = Logger(subsystem: "dev.straxs.Glim", category: "AuditLog")
    private static let fileNamePrefix = "audit-"
    private static let fileExtension = "jsonl"
    private static let dayStampLength = 10
    private static let partNumberDigits = 3
    private static let dayStampStyle = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    private let directory: URL
    private let retention: AuditRetention
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a log that writes into `directory`, creating it on first append.
    ///
    /// - Parameters:
    ///   - directory: Where log files live.
    ///   - retention: Age and size limits.
    ///   - now: The clock; tests pass a fixed date.
    public init(
        directory: URL,
        retention: AuditRetention = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.retention = retention
        self.now = now
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Appends one event, then applies the retention rules.
    public func append(
        _ kind: AuditEventKind, summary: String, details: [String: String] = [:]
    ) throws(AuditLogError) {
        let event = AuditEvent(timestamp: now(), kind: kind, summary: summary, details: details)
        let line = try encodedLine(for: event)
        try createDirectoryIfNeeded()
        let fileURL = try fileURLForAppending(byteCount: line.count)
        try write(line, to: fileURL)
        try applyRetention()
    }

    /// Every stored event, oldest first.
    public func readAllEvents() throws(AuditLogError) -> [AuditEvent] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return []
        }
        var events: [AuditEvent] = []
        for fileURL in try logFiles() {
            events.append(contentsOf: try decodedEvents(in: fileURL))
        }
        return events
    }

    /// Deletes every log file (the "Clear log" button).
    public func clear() throws(AuditLogError) {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return
        }
        for fileURL in try logFiles() {
            try delete(fileURL)
        }
    }

    // MARK: - Writing

    private func encodedLine(for event: AuditEvent) throws(AuditLogError) -> Data {
        do {
            var line = try encoder.encode(event)
            line.append(contentsOf: "\n".utf8)
            return line
        } catch {
            throw .cannotEncode(reason: error.localizedDescription)
        }
    }

    private func createDirectoryIfNeeded() throws(AuditLogError) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            throw .cannotCreateDirectory(
                path: directory.path(percentEncoded: false), reason: error.localizedDescription)
        }
    }

    /// Today's newest part, or the next part number when appending would overflow it.
    private func fileURLForAppending(byteCount: Int) throws(AuditLogError) -> URL {
        let dayStamp = Self.dayStamp(for: now())
        let todaysFiles = try logFiles().filter { Self.dayStamp(of: $0) == dayStamp }
        guard let newestFile = todaysFiles.last else {
            return fileURL(dayStamp: dayStamp, partNumber: 1)
        }
        let newestSize = try fileSize(of: newestFile)
        let fitsInNewestFile =
            newestSize == 0 || newestSize + byteCount <= retention.maximumBytesPerFile
        if fitsInNewestFile {
            return newestFile
        }
        let newestPartNumber = Self.partNumber(of: newestFile) ?? todaysFiles.count
        return fileURL(dayStamp: dayStamp, partNumber: newestPartNumber + 1)
    }

    private func write(_ line: Data, to fileURL: URL) throws(AuditLogError) {
        let path = fileURL.path(percentEncoded: false)
        do {
            guard FileManager.default.fileExists(atPath: path) else {
                try line.write(to: fileURL)
                return
            }
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: line)
            try fileHandle.close()
        } catch {
            throw .cannotWrite(path: path, reason: error.localizedDescription)
        }
    }

    // MARK: - Retention

    private func applyRetention() throws(AuditLogError) {
        let oldestDayToKeep = Self.dayStamp(for: now().addingTimeInterval(-retention.maximumAge))
        for fileURL in try logFiles() where Self.dayStamp(of: fileURL) < oldestDayToKeep {
            try delete(fileURL)
        }
        var remainingFiles = try logFiles()
        var totalBytes = 0
        for fileURL in remainingFiles {
            totalBytes += try fileSize(of: fileURL)
        }
        while totalBytes > retention.maximumTotalBytes, remainingFiles.count > 1 {
            let oldestFile = remainingFiles.removeFirst()
            totalBytes -= try fileSize(of: oldestFile)
            try delete(oldestFile)
        }
    }

    // MARK: - Reading

    private func decodedEvents(in fileURL: URL) throws(AuditLogError) -> [AuditEvent] {
        let path = fileURL.path(percentEncoded: false)
        let contents: String
        do {
            contents = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw .cannotRead(path: path, reason: error.localizedDescription)
        }
        var events: [AuditEvent] = []
        for (lineIndex, line) in contents.split(separator: "\n").enumerated() {
            do {
                events.append(try decoder.decode(AuditEvent.self, from: Data(line.utf8)))
            } catch {
                // A force-quit (the watchdog's designed path) can cut the last line short; one
                // damaged line must not hide the rest of the history.
                Self.logger.warning(
                    "Skipped damaged audit line \(lineIndex + 1, privacy: .public) in \(path, privacy: .public)"
                )
            }
        }
        return events
    }

    // MARK: - Files

    private func logFiles() throws(AuditLogError) -> [URL] {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)
        } catch {
            throw .cannotRead(
                path: directory.path(percentEncoded: false), reason: error.localizedDescription)
        }
        return
            contents
            .filter { fileURL in
                fileURL.lastPathComponent.hasPrefix(Self.fileNamePrefix)
                    && fileURL.pathExtension == Self.fileExtension
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func fileSize(of fileURL: URL) throws(AuditLogError) -> Int {
        let path = fileURL.path(percentEncoded: false)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            guard let size = attributes[.size] as? Int else {
                throw AuditLogError.cannotRead(
                    path: path, reason: "The file has no size attribute.")
            }
            return size
        } catch let auditLogError as AuditLogError {
            throw auditLogError
        } catch {
            throw .cannotRead(path: path, reason: error.localizedDescription)
        }
    }

    private func delete(_ fileURL: URL) throws(AuditLogError) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw .cannotDelete(
                path: fileURL.path(percentEncoded: false), reason: error.localizedDescription)
        }
    }

    private func fileURL(dayStamp: String, partNumber: Int) -> URL {
        let paddedPartNumber = String(partNumber).leftPadded(toLength: Self.partNumberDigits)
        let fileName = "\(Self.fileNamePrefix)\(dayStamp)-\(paddedPartNumber).\(Self.fileExtension)"
        return directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    private static func dayStamp(for date: Date) -> String {
        date.formatted(dayStampStyle)
    }

    private static func dayStamp(of fileURL: URL) -> String {
        String(fileURL.lastPathComponent.dropFirst(fileNamePrefix.count).prefix(dayStampLength))
    }

    private static func partNumber(of fileURL: URL) -> Int? {
        let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
        return nameWithoutExtension.split(separator: "-").last.flatMap { Int($0) }
    }
}

extension String {
    /// Pads with leading zeros, as in part numbers "001".
    fileprivate func leftPadded(toLength length: Int) -> String {
        String(repeating: "0", count: max(0, length - count)) + self
    }
}
