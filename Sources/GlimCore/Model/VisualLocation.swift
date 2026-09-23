/// The model's answer when asked to find a step's control on a window screenshot.
public enum VisualLocation: Sendable, Equatable {
    /// The control's centre on the 0–1000 grid (see ``VisualTarget``), and what is there.
    case found(gridX: Int, gridY: Int, description: String)
    /// Nothing on the screenshot performs the step.
    case notFound(reason: String)
}
