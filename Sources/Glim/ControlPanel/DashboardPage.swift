import AppKit
import GlimCore
import SwiftUI

/// Live status: a hero with the orb, what to try, the health of every part, and today's tasks.
struct DashboardPage: View {
    private struct HealthTile: Identifiable {
        let name: String
        let detail: String
        let systemImage: String
        let isHealthy: Bool?

        var id: String { name }
    }

    /// Placeholder examples shown to new users; any request works.
    private static let suggestions = [
        "Open Notes and write buy milk", "What's on my screen?",
        "Put Notes on the left and Safari on the right", "Play music",
    ]

    /// Tunable: the hero orb's frame rate; the panel doesn't need the display's full rate.
    private static let heroOrbFramesPerSecond = 30.0

    @Environment(AppModel.self) private var model
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero
            GlassCard(title: "Try saying", systemImage: "quote.bubble", tint: .cyan) {
                FlowingChips(texts: Self.suggestions)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], alignment: .leading,
                spacing: 12
            ) {
                ForEach(healthTiles) { tile in
                    healthTileView(tile)
                }
            }
            if let lastCrash = model.lastCrash {
                GlassCard(title: "Last crash", systemImage: "exclamationmark.triangle", tint: .red)
                {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lastCrash.date, format: .dateTime.day().month().hour().minute())
                            Text(lastCrash.description)
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Show report") {
                            NSWorkspace.shared.activateFileViewerSelecting([lastCrash.reportURL])
                        }
                    }
                }
            } else if let crashReadError = model.crashReadError {
                Label(crashReadError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            GlassCard(title: "Today", systemImage: "clock", tint: .indigo) {
                if let todaysTasksError = model.todaysTasksError {
                    Label(todaysTasksError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else if model.todaysTasks.isEmpty {
                    Text(
                        "No tasks yet today. Hold \(HotkeyCombo.pushToTalk.displayName) and say what you want."
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.todaysTasks.enumerated()), id: \.offset) { _, event in
                        HStack(spacing: 10) {
                            Image(systemName: icon(forTaskSummary: event.summary))
                                .foregroundStyle(color(forTaskSummary: event.summary))
                            Text(event.summary).lineLimit(1)
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task { await refresh() }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(spacing: 22) {
            GlimOrbView(
                mood: model.isArmed ? .listening(level: 0.25) : .alert,
                maximumFramesPerSecond: Self.heroOrbFramesPerSecond,
                isPaused: controlActiveState == .inactive
            )
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.isArmed ? "Ready when you are" : "Glim is stopped")
                    .font(.system(size: 22, weight: .bold))
                Text(
                    model.isArmed
                        ? "Hold \(HotkeyCombo.pushToTalk.displayName) and say what you want. Low-risk plans run at once; anything risky asks you."
                        : (model.tripReason?.explanation ?? "")
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if !model.isArmed {
                    Button("Re-arm") { model.rearm() }
                        .buttonStyle(.glassProminent)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface(cornerRadius: 22, tint: model.isArmed ? .cyan : .red)
    }

    // MARK: - Health

    private var healthTiles: [HealthTile] {
        [
            HealthTile(
                name: "Watchdog", detail: watchdogDetail, systemImage: "shield.checkered",
                isHealthy: model.watchdogState == .ready),
            HealthTile(
                name: "Action mode",
                detail: model.isActionModeAvailable ? "On" : actionModeOffReason,
                systemImage: "hand.tap", isHealthy: model.isActionModeAvailable),
            HealthTile(
                name: "Planner", detail: model.ollamaStatus.detail, systemImage: "cpu",
                isHealthy: model.ollamaStatus.isHealthy),
            HealthTile(
                name: "Laya checker", detail: model.layaStatus.detail,
                systemImage: "checkmark.shield",
                isHealthy: model.layaStatus.isHealthy),
            HealthTile(
                name: "Jev checker",
                detail: model.settings.jev.isEnabled ? "On (cloud)" : "Off",
                systemImage: "cloud", isHealthy: nil),
            HealthTile(
                name: "Talk key", detail: "Hold \(HotkeyCombo.pushToTalk.displayName)",
                systemImage: "mic", isHealthy: nil),
        ]
    }

    private func healthTileView(_ tile: HealthTile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tile.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint(for: tile.isHealthy))
                .frame(width: 34, height: 34)
                .background(tint(for: tile.isHealthy).opacity(0.15), in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(tile.name).font(.system(size: 13, weight: .semibold))
                Text(tile.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .panelSurface(cornerRadius: 14)
    }

    private func tint(for isHealthy: Bool?) -> Color {
        isHealthy.map { $0 ? .green : .red } ?? .secondary
    }

    private var watchdogDetail: String {
        switch model.watchdogState {
        case .starting: "Starting…"
        case .ready: "Running · \(HotkeyCombo.killSwitch.displayName) stops Glim"
        case .hotkeyFailed: "⌃⌥⌘K is taken by another app"
        case .notRunning(let reason): reason
        }
    }

    private var actionModeOffReason: String {
        if !model.isEnglishInterface {
            return "Off: the system language isn't English"
        }
        return "Off: the watchdog isn't ready"
    }

    // MARK: - Today

    private func icon(forTaskSummary summary: String) -> String {
        summary.contains("completed") || summary.contains("answered")
            ? "checkmark.circle.fill" : "xmark.octagon.fill"
    }

    private func color(forTaskSummary summary: String) -> Color {
        summary.contains("completed") || summary.contains("answered") ? .green : .orange
    }

    private func refresh() async {
        async let health: Void = model.refreshServiceHealth()
        async let tasks: Void = model.refreshTodaysTasks()
        async let crash: Void = model.refreshLastCrash()
        _ = await (health, tasks, crash)
    }
}

/// Short phrases laid out as wrapping chips.
private struct FlowingChips: View {
    let texts: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(texts, id: \.self) { text in
                Text("“\(text)”")
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.07), in: .capsule)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
            }
        }
    }
}
