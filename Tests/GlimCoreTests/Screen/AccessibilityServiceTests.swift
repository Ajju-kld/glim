import Testing

@testable import GlimCore

struct AccessibilityServiceTests {
    @Test func untrustedProcessIsRefusedWithAClearError() async {
        guard !AccessibilityService.isTrusted else {
            return
        }
        let finder = ResolvedApp(
            identity: AppIdentity(
                bundleIdentifier: "com.apple.finder", displayName: "Finder", hasValidSignature: true
            ),
            bundleURL: nil, processIdentifier: 1)

        await #expect(throws: ScreenReadingError.accessibilityNotTrusted) {
            _ = try await AccessibilityService().snapshotFrontWindow(of: finder)
        }
    }

    @Test(.enabled(if: AccessibilityService.isTrusted, "Needs Accessibility permission"))
    func frontmostAppWindowCanBeRead() async throws {
        let resolver = AppResolver(
            catalog: WorkspaceAppCatalog(), verifier: CodeSignatureVerifier())
        let frontmostApp = try #require(resolver.frontmostApp())

        let snapshot = try await AccessibilityService().snapshotFrontWindow(of: frontmostApp)

        #expect(snapshot.table.elements.count <= ScreenReadingLimits.maximumListedElements)
        #expect(snapshot.table.elements.allSatisfy { !$0.isSecureTextField })
    }
}
