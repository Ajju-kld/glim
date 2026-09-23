/// What happened when settings were loaded at launch.
public enum SettingsLoadOutcome: Sendable, Equatable {
    /// The sealed file was valid and is now in use.
    case loaded
    /// No file existed; safe defaults were saved.
    case createdWithSafeDefaults
    /// The file could not be read or decoded; safe defaults were restored and saved.
    case resetBecauseCorrupted
    /// The file was edited outside Glim or sealed with another key; safe defaults were restored.
    case resetBecauseSealInvalid
}
