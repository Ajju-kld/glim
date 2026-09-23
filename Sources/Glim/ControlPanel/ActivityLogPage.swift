import GlimCore
import SwiftUI

/// Everything Glim heard, planned, checked and did, newest first. Kept 7 days, at most 5 MB.
struct ActivityLogPage: View {
    @Environment(AppModel.self) private var model
    @State private var events: [AuditEvent] = []
    @State private var searchText = ""
    @State private var loadError: String?
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search the log", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Spacer()
                Button("Refresh") { Task { await load() } }
                Button("Clear log…", role: .destructive) { isConfirmingClear = true }
            }
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filteredEvents.enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(event.timestamp, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(event.kind.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(width: 150, alignment: .leading)
                        Text(event.summary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
            .padding(12)
            .panelSurface(cornerRadius: 16)
        }
        .task { await load() }
        .confirmationDialog("Delete the whole activity log?", isPresented: $isConfirmingClear) {
            Button("Clear log", role: .destructive) { Task { await clear() } }
        }
    }

    private var filteredEvents: [AuditEvent] {
        guard !searchText.isEmpty else {
            return events
        }
        return events.filter {
            $0.summary.localizedCaseInsensitiveContains(searchText)
                || $0.kind.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func load() async {
        do {
            events = try await model.services.auditLog.readAllEvents().reversed()
            loadError = nil
        } catch {
            loadError = "Could not read the log: \(error)"
        }
    }

    private func clear() async {
        do {
            try await model.services.auditLog.clear()
            events = []
        } catch {
            loadError = "Could not clear the log: \(error)"
        }
    }
}
