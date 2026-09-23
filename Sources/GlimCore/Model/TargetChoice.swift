/// The model's pick for one step's target.
public enum TargetChoice: Sendable, Equatable {
    /// The chosen element, guaranteed to be a compatible element of the table it was picked from,
    /// and who chose it.
    case element(UIElementSnapshot, pickedBy: PickSource)
    /// The model found no suitable control.
    case blocked(reason: String)
}
