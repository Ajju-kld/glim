import Foundation
import Testing

@testable import GlimCore

struct CodeSignatureVerifierTests {
    let verifier = CodeSignatureVerifier()
    let calculatorURL = URL(filePath: "/System/Applications/Calculator.app")

    @Test func appleAppWithMatchingIdentifierIsTrusted() {
        #expect(
            verifier.hasTrustedSignature(
                bundleIdentifier: "com.apple.calculator", bundleURL: calculatorURL,
                processIdentifier: nil))
    }

    @Test func appClaimingAnotherIdentifierIsNotTrusted() {
        #expect(
            !verifier.hasTrustedSignature(
                bundleIdentifier: "com.apple.Notes", bundleURL: calculatorURL,
                processIdentifier: nil))
    }

    @Test func missingBundleIsNotTrusted() {
        #expect(
            !verifier.hasTrustedSignature(
                bundleIdentifier: "com.apple.calculator",
                bundleURL: URL(filePath: "/Applications/Does Not Exist.app"),
                processIdentifier: nil))
    }

    @Test func nothingToCheckIsNotTrusted() {
        #expect(
            !verifier.hasTrustedSignature(
                bundleIdentifier: "com.apple.calculator", bundleURL: nil, processIdentifier: nil))
    }

    @Test func appleIdentifiersRequireApplesOwnAnchor() {
        #expect(
            CodeSignatureVerifier.requirementText(for: "com.apple.Notes")
                == #"identifier "com.apple.Notes" and anchor apple"#)
        #expect(
            CodeSignatureVerifier.requirementText(for: "com.tinyspeck.slackmacgap")
                == #"identifier "com.tinyspeck.slackmacgap" and anchor apple generic"#)
    }

    @Test(arguments: [#"com.evil" or true"#, "", "com.apple.Notes\n"])
    func malformedIdentifiersAreRejected(bundleIdentifier: String) {
        #expect(CodeSignatureVerifier.requirementText(for: bundleIdentifier) == nil)
    }
}
