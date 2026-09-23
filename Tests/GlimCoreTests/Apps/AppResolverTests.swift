import Foundation
import Testing

@testable import GlimCore

struct FakeAppCatalog: AppCatalog {
    var installed: [InstalledApp]
    var running: [RunningApp]

    func installedApps() -> [InstalledApp] { installed }
    func runningApps() -> [RunningApp] { running }
}

struct FakeSignatureVerifier: SignatureVerifying {
    let trustedBundleIdentifiers: Set<String>

    func hasTrustedSignature(
        bundleIdentifier: String, bundleURL: URL?, processIdentifier: pid_t?
    ) -> Bool {
        trustedBundleIdentifiers.contains(bundleIdentifier)
    }
}

struct AppResolverTests {
    let notesURL = URL(filePath: "/System/Applications/Notes.app")
    let codeURL = URL(filePath: "/Applications/Visual Studio Code.app")

    func makeResolver(trusted: Set<String> = ["com.apple.Notes", "com.microsoft.VSCode"])
        -> AppResolver
    {
        let catalog = FakeAppCatalog(
            installed: [
                InstalledApp(
                    name: "Notes", fileName: "Notes", bundleIdentifier: "com.apple.Notes",
                    url: notesURL),
                InstalledApp(
                    name: "Code", fileName: "Visual Studio Code",
                    bundleIdentifier: "com.microsoft.VSCode",
                    url: codeURL),
            ],
            running: [
                RunningApp(
                    name: "Finder", bundleIdentifier: "com.apple.finder", processIdentifier: 100,
                    isFrontmost: true, bundleURL: nil),
                RunningApp(
                    name: "Notes", bundleIdentifier: "com.apple.Notes", processIdentifier: 200,
                    isFrontmost: false, bundleURL: notesURL),
            ])
        return AppResolver(
            catalog: catalog, verifier: FakeSignatureVerifier(trustedBundleIdentifiers: trusted))
    }

    @Test func runningAppIsPreferredAndCarriesItsProcess() throws {
        let resolved = try #require(makeResolver().resolve(appNamed: "Notes"))

        #expect(
            resolved.identity
                == AppIdentity(
                    bundleIdentifier: "com.apple.Notes", displayName: "Notes",
                    hasValidSignature: true))
        #expect(resolved.processIdentifier == 200)
    }

    @Test(arguments: ["notes", "  Notes ", "Notes.app", "NOTES"])
    func namesMatchLoosely(spokenName: String) {
        #expect(
            makeResolver().resolve(appNamed: spokenName)?.identity.bundleIdentifier
                == "com.apple.Notes")
    }

    @Test func installedAppMatchesByFileNameToo() {
        let resolved = makeResolver().resolve(appNamed: "Visual Studio Code")

        #expect(resolved?.identity.bundleIdentifier == "com.microsoft.VSCode")
        #expect(resolved?.processIdentifier == nil)
        #expect(resolved?.bundleURL == codeURL)
    }

    @Test func unknownAppResolvesToNothing() {
        #expect(makeResolver().resolve(appNamed: "Photoshop") == nil)
    }

    @Test func untrustedSignatureIsRecorded() {
        let resolved = makeResolver(trusted: []).resolve(appNamed: "Notes")

        #expect(resolved?.identity.hasValidSignature == false)
    }

    @Test func frontmostAppIsFound() {
        #expect(makeResolver().frontmostApp()?.identity.bundleIdentifier == "com.apple.finder")
    }

    @Test func runningOnlyLookupIgnoresInstalledApps() {
        #expect(makeResolver().resolveRunning(appNamed: "Visual Studio Code") == nil)
        #expect(makeResolver().resolveRunning(appNamed: "Notes")?.processIdentifier == 200)
    }

    @Test func appNamesForThePlannerAreSortedAndUnique() {
        let resolver = makeResolver()

        #expect(resolver.installedAppNames() == ["Code", "Notes"])
        #expect(resolver.runningAppNames() == ["Finder", "Notes"])
    }
}
