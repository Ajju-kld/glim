import Foundation

/// Stores the TypeSafe (Jev) API key in the login Keychain — never in the settings file.
public struct KeychainSecretStore: Sendable {
    private static let jevService = "dev.straxs.Glim.jev"
    private static let jevAccount = "api-key"

    /// Creates the store.
    public init() {}

    /// The saved Jev key.
    public func jevAPIKey() throws(KeychainError) -> String {
        guard
            let keyData = try KeychainItem.read(service: Self.jevService, account: Self.jevAccount),
            let key = String(data: keyData, encoding: .utf8), !key.isEmpty
        else {
            throw .missingSecret
        }
        return key
    }

    /// Whether a Jev key is saved.
    public func hasJevAPIKey() -> Bool {
        do {
            return !(try jevAPIKey()).isEmpty
        } catch {
            return false
        }
    }

    /// Saves (or replaces) the Jev key.
    public func saveJevAPIKey(_ key: String) throws(KeychainError) {
        try KeychainItem.save(Data(key.utf8), service: Self.jevService, account: Self.jevAccount)
    }

    /// Removes the Jev key.
    public func deleteJevAPIKey() throws(KeychainError) {
        try KeychainItem.delete(service: Self.jevService, account: Self.jevAccount)
    }
}
