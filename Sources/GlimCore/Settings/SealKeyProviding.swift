import CryptoKit

/// Supplies the secret key that seals the settings file. The live provider keeps it in the
/// Keychain; tests pass a fixed key.
public protocol SealKeyProviding: Sendable {
    /// The key, created on first use.
    func sealKey() throws -> SymmetricKey
}
