import CryptoKit
import Foundation

/// HMAC-SHA256 seal over the settings bytes, so a file edited outside Glim is detected.
enum SettingsSeal {
    static func seal(_ settingsData: Data, with key: SymmetricKey) -> String {
        Data(HMAC<SHA256>.authenticationCode(for: settingsData, using: key)).base64EncodedString()
    }

    /// Compares in constant time, so the check can't leak how much of a forged seal was right.
    static func isValid(_ seal: String, for settingsData: Data, with key: SymmetricKey) -> Bool {
        guard let sealData = Data(base64Encoded: seal) else {
            return false
        }
        return HMAC<SHA256>.isValidAuthenticationCode(
            sealData, authenticating: settingsData, using: key)
    }
}
