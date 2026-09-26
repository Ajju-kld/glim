import Foundation
import Testing

@testable import GlimCore

/// Answers each app's read from a table or an error chosen per bundle identifier.
struct PerAppScreenReader: ScreenReading {
    let tables: [String: ElementTable]
    let errors: [String: ScreenReadingError]

    func snapshotFrontWindow(of app: ResolvedApp) async throws(ScreenReadingError)
        -> ScreenSnapshot
    {
        if let error = errors[app.identity.bundleIdentifier] {
            throw error
        }
        let table =
            tables[app.identity.bundleIdentifier]
            ?? ElementTable(
                elements: [], handleIndexByElementNumber: [:], readableText: "",
                wasTruncated: false)
        return ScreenSnapshot(app: app, windowTitle: app.identity.displayName, table: table)
    }

    func returnKeyTargetTexts(in app: ResolvedApp) async -> [String] { [] }

    func focusedControlIsBrowserAddressBar(in app: ResolvedApp) async -> Bool { false }
}

struct ReadCheckTests {
    static func app(_ name: String, _ bundleIdentifier: String) -> ResolvedApp {
        ResolvedApp(
            identity: AppIdentity(
                bundleIdentifier: bundleIdentifier, displayName: name, hasValidSignature: true),
            bundleURL: nil, processIdentifier: 10)
    }

    static func table(controls: Int, greyedOut: Int = 0, unnamed: Int = 0, cutOff: Bool = false)
        -> ElementTable
    {
        let elements = (0..<controls).map { index in
            UIElementSnapshot.fixture(number: index + 1, label: "Control \(index + 1)")
        }
        return ElementTable(
            elements: elements, handleIndexByElementNumber: [:], readableText: "",
            wasTruncated: cutOff,
            disabledControlLabels: (0..<greyedOut).map { "Greyed \($0)" },
            unlabelledControlCount: unnamed)
    }

    static let notes = app("Notes", "com.apple.Notes")
    static let spotify = app("Spotify", "com.spotify.client")
    static let calculator = app("Calculator", "com.apple.calculator")
    static let passwords = app("Passwords", "com.apple.Passwords")
    static let glim = app("Glim", "dev.straxs.Glim")
    static let frozen = app("Frozen", "dev.example.frozen")

    func makeCheck(
        tables: [String: ElementTable] = [:], errors: [String: ScreenReadingError] = [:]
    ) -> ReadCheck {
        ReadCheck(
            reader: PerAppScreenReader(tables: tables, errors: errors),
            trust: SafetyPolicy.safeDefaults.appTrust)
    }

    @Test func eachAppGetsItsResult() async {
        let check = makeCheck(
            tables: [
                "com.apple.Notes": Self.table(controls: 80, greyedOut: 2, unnamed: 1, cutOff: true),
                "com.apple.calculator": Self.table(controls: 3),
            ],
            errors: ["dev.example.frozen": .appNotResponding(appName: "Frozen")])

        let results = await check.run(on: [Self.notes, Self.spotify, Self.calculator, Self.frozen])

        #expect(
            results.map(\.outcome) == [
                .readable(.init(listed: 80, greyedOut: 2, unnamed: 1, wasCutOff: true)),
                .nothingReadable(.init(listed: 0, greyedOut: 0, unnamed: 0, wasCutOff: false)),
                .thin(.init(listed: 3, greyedOut: 0, unnamed: 0, wasCutOff: false)),
                .couldNotRead(
                    reason: ScreenReadingError.appNotResponding(appName: "Frozen").explanation),
            ])
    }

    @Test func neverTouchAppsAndGlimItselfAreSkippedUnread() async {
        let check = makeCheck(errors: [
            "com.apple.Passwords": .appNotResponding(appName: "read anyway"),
            "dev.straxs.Glim": .appNotResponding(appName: "read anyway"),
        ])

        let results = await check.run(on: [Self.passwords, Self.glim])

        #expect(results.allSatisfy { if case .skipped = $0.outcome { true } else { false } })
    }

    @Test func summaryHasCountsButNoControlNames() async {
        let check = makeCheck(tables: ["com.apple.Notes": Self.table(controls: 80, greyedOut: 2)])

        let results = await check.run(on: [Self.notes, Self.spotify])
        let summary = ReadCheck.summary(of: results)

        #expect(summary.contains("Notes: readable, 80 controls"))
        #expect(summary.contains("2 greyed out"))
        #expect(summary.contains("Spotify: nothing readable"))
        #expect(!summary.contains("Control 1"))
        #expect(!summary.contains("Greyed 0"))
    }
}
