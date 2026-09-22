/// What Glim sees in the front window at one moment.
public struct ScreenSnapshot: Sendable, Equatable {
    /// The app that owns the window.
    public let app: ResolvedApp
    /// The window's title, if any.
    public let windowTitle: String?
    /// The numbered controls and readable text.
    public let table: ElementTable

    /// Creates a snapshot.
    public init(app: ResolvedApp, windowTitle: String?, table: ElementTable) {
        self.app = app
        self.windowTitle = windowTitle
        self.table = table
    }
}
