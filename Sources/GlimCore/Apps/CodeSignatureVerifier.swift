import Foundation
import Security

/// Verifies apps with the Security framework.
///
/// A valid signature is not enough — an ad-hoc-signed impostor is "valid" too. The signature
/// must also satisfy a requirement: its signing identifier equals the claimed bundle identifier,
/// and it chains to Apple (`anchor apple` for `com.apple.*` apps, `anchor apple generic` — Mac
/// App Store, Developer ID or Apple Development — for everyone else).
public struct CodeSignatureVerifier: SignatureVerifying {
    private static let appleBundlePrefix = "com.apple."
    private static let allowedIdentifierCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    /// Creates a verifier.
    public init() {}

    /// Checks the running process when there is one (fast; the kernel tracks its signature),
    /// otherwise the bundle on disk without re-hashing every resource.
    public func hasTrustedSignature(
        bundleIdentifier: String, bundleURL: URL?, processIdentifier: pid_t?
    ) -> Bool {
        guard let requirementText = Self.requirementText(for: bundleIdentifier),
            let requirement = Self.requirement(from: requirementText)
        else {
            return false
        }
        if let processIdentifier, let runningCode = Self.runningCode(for: processIdentifier) {
            return SecCodeCheckValidity(runningCode, [], requirement) == errSecSuccess
        }
        if let bundleURL, let staticCode = Self.staticCode(at: bundleURL) {
            let flags = SecCSFlags(rawValue: kSecCSDoNotValidateResources)
            return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
        }
        return false
    }

    /// The code-signing requirement for `bundleIdentifier`, or nil when the identifier contains
    /// characters that could change the requirement's meaning.
    static func requirementText(for bundleIdentifier: String) -> String? {
        let hasOnlyAllowedCharacters = bundleIdentifier.unicodeScalars.allSatisfy {
            allowedIdentifierCharacters.contains($0)
        }
        guard !bundleIdentifier.isEmpty, hasOnlyAllowedCharacters else {
            return nil
        }
        let anchor =
            bundleIdentifier.hasPrefix(appleBundlePrefix) ? "anchor apple" : "anchor apple generic"
        return "identifier \"\(bundleIdentifier)\" and \(anchor)"
    }

    private static func requirement(from text: String) -> SecRequirement? {
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(text as CFString, [], &requirement)
        return status == errSecSuccess ? requirement : nil
    }

    private static func runningCode(for processIdentifier: pid_t) -> SecCode? {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: processIdentifier] as CFDictionary
        let status = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        return status == errSecSuccess ? code : nil
    }

    private static func staticCode(at bundleURL: URL) -> SecStaticCode? {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode)
        return status == errSecSuccess ? staticCode : nil
    }
}
