import CryptoKit
import Foundation

/// Keeps the settings-seal key in the login Keychain, creating it on first launch.
public struct KeychainSealKeyProvider: SealKeyProviding {
    private static let service = "dev.straxs.Glim.settings-seal"
    private static let account = "settings"

    /// Creates the provider.
    public init() {}

    /// The existing key, or a new random 256-bit key saved for next time.
    public func sealKey() throws -> SymmetricKey {
        if let storedKey = try KeychainItem.read(service: Self.service, account: Self.account) {
            return SymmetricKey(data: storedKey)
        }
        let newKey = SymmetricKey(size: .bits256)
        try KeychainItem.save(
            newKey.withUnsafeBytes { Data($0) }, service: Self.service, account: Self.account)
        return newKey
    }
}
