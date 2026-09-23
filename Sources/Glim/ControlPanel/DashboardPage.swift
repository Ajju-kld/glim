import GlimCore
import SwiftUI

/// Live status: armed or stopped, the big STOP, health of every part, and today's tasks.
struct DashboardPage: View {
    @Environment(AppModel.self) private var model
    @State private var ollamaStatus = ServiceHealth.Status.checking
    @State private var layaStatus = ServiceHealth.Status.checking
    @State private var todaysTasks: [AuditEvent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                armedCard
                stopCard
            }
            GlassCard(title: "Health", systemImage: "heart.text.square") {
                StatusRow(
                    name: "Watchdog (\(HotkeyCombo.killSwitch.displayName))",
                    detail: watchdogDetail, isHealthy: model.watchdogState == .ready)
                StatusRow(
                    name: "Action mode",
                    detail: model.isActionModeAvailable ? "On" : actionModeOffReason,
                    isHealthy: model.isActionModeAvailable)
                StatusRow(
                    name: "Planner (Ollama)", detail: ollamaStatus.detail,
                    isHealthy: ollamaStatus.isHealthy)
                StatusRow(
                    name: "Laya checker", detail: layaStatus.detail, isHealthy: layaStatus.isHealthy
                )
                StatusRow(
                    name: "Jev checker",
                    detail: model.settings.jev.isEnabled ? "On (cloud)" : "Off", isHealthy: nil)
                StatusRow(
                    name: "Talk", detail: "Hold \(HotkeyCombo.pushToTalk.displayName)",
                    isHealthy: nil)
            }
            GlassCard(title: "Today", systemImage: "clock") {
                if todaysTasks.isEmpty {
                    Text(
                        "No tasks yet today. Hold \(HotkeyCombo.pushToTalk.displayName) and say what you want."
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(todaysTasks.enumerated()), id: \.offset) { _, event in
                        HStack {
                            Text(event.summary).lineLimit(1)
                            Spacer()
                            Text(event.timestamp, style: .time).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task { await refresh() }
    }

    private var armedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(model.isArmed ? .green : .red).frame(width: 12, height: 12)
                Text(model.isArmed ? "ARMED" : "STOPPED").font(.title2.weight(.bold))
            }
            Text(model.isArmed ? "Ready when you are." : (model.tripReason?.explanation ?? ""))
                .foregroundStyle(.secondary)
            if !model.isArmed {
                Button("Re-arm") { model.rearm() }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private var stopCard: some View {
        Button {
            model.stopEverything()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "stop.fill").font(.system(size: 28, weight: .bold))
                Text("STOP").font(.title3.weight(.bold))
                Text(HotkeyCombo.killSwitch.displayName).font(.caption.monospaced())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(.red.gradient, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop Glim")
    }

    private var watchdogDetail: String {
        switch model.watchdogState {
        case .starting: "Starting…"
        case .ready: "Running"
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

    private func refresh() async {
        async let ollama = ServiceHealth.ollamaStatus(
            modelName: model.settings.plannerModelName, transport: model.services.transport)
        async let laya = ServiceHealth.layaStatus(transport: model.services.transport)
        ollamaStatus = await ollama
        layaStatus = await laya
        do {
            let startOfToday = Calendar.current.startOfDay(for: .now)
            todaysTasks = try await model.services.auditLog.readAllEvents()
                .filter { $0.kind == .taskFinished && $0.timestamp >= startOfToday }
                .reversed()
        } catch {
            todaysTasks = []
        }
    }
}
