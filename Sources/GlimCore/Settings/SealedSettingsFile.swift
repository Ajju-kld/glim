/// The on-disk format: the settings JSON exactly as sealed, plus its seal. Keeping the JSON as
/// a string means the seal covers the exact bytes that are later decoded.
struct SealedSettingsFile: Codable {
    let settingsJSON: String
    let seal: String
}
