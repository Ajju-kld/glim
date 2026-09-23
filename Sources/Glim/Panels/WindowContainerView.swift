import AppKit
import SwiftUI

/// A plain view that holds a SwiftUI hosting view and fills the window.
///
/// When a hosting view is itself a window's content view, SwiftUI resizes and re-measures the
/// window whenever its content changes. Glim's orbs change every frame, and that feedback made
/// AppKit run layout inside layout until it threw ("too many Update Constraints passes") and
/// crashed the app when the talk key was pressed. Nested in this container, the hosting view
/// just fills the window, and the window keeps the frame Glim gives it.
final class WindowContainerView: NSView {
    /// A container of `size` whose hosting view shows `rootView` and follows the container's size.
    static func hosting<Content: View>(_ rootView: Content, size: CGSize) -> WindowContainerView {
        let container = WindowContainerView(frame: CGRect(origin: .zero, size: size))
        let hostingView = ClickThroughHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        return container
    }
}
