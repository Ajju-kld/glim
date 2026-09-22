/// Why settings could not be changed or saved.
public enum SettingsStoreError: Error, Sendable, Equatable {
    /// The change loosens safety and the owner did not confirm with Touch ID or password.
    case ownerNotConfirmed([SettingsLoosening])
    /// Settings changed while the owner was being asked; the change was not applied.
    case settingsChangedDuringConfirmation
    /// The model name is a cloud model or malformed; only local models are allowed.
    case plannerModelNotLocal(modelName: String)
    case cannotSave(reason: String)
    case sealKeyUnavailable(reason: String)
    case auditFailed(reason: String)
}
