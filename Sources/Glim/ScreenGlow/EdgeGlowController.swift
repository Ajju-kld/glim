import AppKit
import GlimCore
import SwiftUI

/// Owns screen chat's two windows: the glow around the main screen and the caption bar at its
/// bottom. Both are borderless, click-through, above every app and Space (full-screen apps
/// too), and hidden from screen capture, so neither ends up in a screenshot Glim reads.
@MainActor
final class EdgeGlowController {
    /// Tunable: how long the glow and caption take to fade in and out.
    private static let fadeSeconds = 0.45
    /// Tunable: the rounding of the screen's corners the glow follows. Notched MacBook screens
    /// have rounded top corners of about this size.
    private static let screenCornerRadius: CGFloat = 12
    /// Tunable: the caption's widest size, its share of the screen width, and its distance from
    /// the bottom edge.
    private static let captionMaximumWidth: CGFloat = 760
    private static let captionScreenFraction: CGFloat = 0.6
    private static let captionBottomMargin: CGFloat = 56

    private let glowPanel = EdgeGlowController.makeOverlayPanel()
    private let captionPanel = EdgeGlowController.makeOverlayPanel()
    private let glowView = EdgeGlowLayerView(cornerRadius: EdgeGlowController.screenCornerRadius)
    private let captionHost = NSHostingController(rootView: ScreenChatCaptionView(text: ""))
    private var shownCaption: String?
    /// The pending "remove once faded" for each window, so fading one never cancels the other.
    private var hideTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init() {
        glowPanel.contentView = glowView
        captionPanel.contentView = captionHost.view
    }

    /// Fades the glow in around the main screen.
    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        if glowPanel.frame != screen.frame {
            glowPanel.setFrame(screen.frame, display: false)
        }
        fade(glowPanel, in: true)
    }

    /// Shows `appearance`; the glow redraws only when it differs from what is shown.
    func apply(_ appearance: EdgeGlowAppearance) {
        glowView.apply(appearance)
    }

    /// Shows `text` in the caption bar at the bottom of the screen, or hides the bar for nil.
    /// Unchanged text does nothing.
    func showCaption(_ text: String?) {
        guard text != shownCaption else {
            return
        }
        shownCaption = text
        guard let text, !text.isEmpty,
            let screen = NSScreen.main ?? NSScreen.screens.first
        else {
            fade(captionPanel, in: false)
            return
        }
        captionHost.rootView = ScreenChatCaptionView(text: text)
        let width = min(Self.captionMaximumWidth, screen.frame.width * Self.captionScreenFraction)
        let height = captionHost.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height
        captionPanel.setFrame(
            CGRect(
                x: screen.frame.midX - width / 2,
                y: screen.visibleFrame.minY + Self.captionBottomMargin, width: width,
                height: height),
            display: true)
        fade(captionPanel, in: true)
    }

    /// Fades the glow and caption out.
    func hide() {
        shownCaption = nil
        fade(glowPanel, in: false)
        fade(captionPanel, in: false)
    }

    private func fade(_ panel: NSPanel, in isShowing: Bool) {
        let panelIdentifier = ObjectIdentifier(panel)
        hideTasks[panelIdentifier]?.cancel()
        hideTasks[panelIdentifier] = nil
        if isShowing, !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        guard panel.isVisible else {
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeSeconds
            panel.animator().alphaValue = isShowing ? 1 : 0
        }
        guard !isShowing else {
            return
        }
        hideTasks[panelIdentifier] = Task { [panel] in
            do {
                try await Task.sleep(for: .seconds(Self.fadeSeconds))
            } catch {
                // Cancelled because screen chat is showing again, so the window must stay.
                return
            }
            if panel.alphaValue == 0 {
                panel.orderOut(nil)
            }
        }
    }

    private static func makeOverlayPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]
        return panel
    }
}

/// The caption bar: what you're saying while you speak, then Glim's answer.
struct ScreenChatCaptionView: View {
    /// Tunable: the most lines shown; longer answers end with "…".
    private static let maximumLines = 3

    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(Self.maximumLines)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.62), in: .rect(cornerRadius: 18, style: .continuous))
            .accessibilityLabel(text)
    }
}
