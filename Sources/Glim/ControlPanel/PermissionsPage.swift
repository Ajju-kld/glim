import AVFoundation
import AppKit
import GlimCore
import Speech
import SwiftUI

/// The four permissions Glim uses, with buttons that open the right System Settings pane.
/// Glim never changes these settings itself.
struct PermissionsPage: View {
    private struct Permission: Identifiable {
        let name: String
        let purpose: String
        let isGranted: Bool
        let settingsAnchor: String

        var id: String { name }
    }

    private static let privacySettingsURL =
        "x-apple.systempreferences:com.apple.preference.security?"
    private static let screenRecordingAnchor = "Privacy_ScreenCapture"

    @State private var refreshCount = 0
    /// Checked when the page opens and on Refresh, not on every redraw.
    @State private var permissions: [Permission] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard(title: "Permissions", systemImage: "lock.shield", tint: .blue) {
                ForEach(permissions) { permission in
                    HStack(spacing: 12) {
                        Image(
                            systemName: permission.isGranted
                                ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(permission.isGranted ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(permission.name)
                            Text(permission.purpose).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") { openSettings(anchor: permission.settingsAnchor) }
                    }
                }
            }
            HStack {
                Button("Ask for Accessibility") { AccessibilityService.promptForTrust() }
                Button("Ask for Screen Recording") { askForScreenRecording() }
                Button("Refresh") { refreshCount += 1 }
            }
            Text(
                "macOS lists Glim under Screen Recording only after Glim asks once. Screen Recording is optional: Glim only looks at a window when its text isn't enough to answer a question."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Text("To revoke a permission later, switch Glim off in the same System Settings pane.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .task(id: refreshCount) { permissions = Self.currentPermissions() }
    }

    private static func currentPermissions() -> [Permission] {
        [
            Permission(
                name: "Microphone", purpose: "Hear you while the talk key is held",
                isGranted: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                settingsAnchor: "Privacy_Microphone"),
            Permission(
                name: "Speech Recognition", purpose: "Turn speech into text on this Mac",
                isGranted: SFSpeechRecognizer.authorizationStatus() == .authorized,
                settingsAnchor: "Privacy_SpeechRecognition"),
            Permission(
                name: "Accessibility", purpose: "Read buttons and fields, click and type",
                isGranted: AccessibilityService.isTrusted, settingsAnchor: "Privacy_Accessibility"),
            Permission(
                name: "Screen Recording",
                purpose: "Look at a window only when its text isn't enough",
                isGranted: CGPreflightScreenCaptureAccess(),
                settingsAnchor: Self.screenRecordingAnchor
            ),
        ]
    }

    /// Asks macOS for Screen Recording. The first request adds Glim to the list in System
    /// Settings; after that, macOS only changes it from Settings, so the pane is opened too.
    private func askForScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            openSettings(anchor: Self.screenRecordingAnchor)
        }
        refreshCount += 1
    }

    private func openSettings(anchor: String) {
        guard let settingsURL = URL(string: Self.privacySettingsURL + anchor) else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }
}
