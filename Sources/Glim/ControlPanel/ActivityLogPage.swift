import GlimCore
import SwiftUI

/// Everything Glim heard, planned, checked and did, newest first. Kept 7 days, at most 5 MB.
struct ActivityLogPage: View {
    /// One event with a stable identity: its position in the log, oldest first, so new
    /// entries don't renumber the old ones.
    private struct LogRow: Identifiable {
        let id: Int
        let event: AuditEvent
    }

    /// Tunable: most rows drawn at once; searching narrows the rest.
    private static let maximumShownRows = 300

    @Environment(AppModel.self) private var model
    @State private var rows: [LogRow] = []
    @State private var shownRows: [LogRow] = []
    @State private var matchingRowCount = 0
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
            if matchingRowCount > shownRows.count {
                Text(
                    "Showing the newest \(shownRows.count) of \(matchingRowCount) entries. Search to find older ones."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(shownRows) { row in
                    let event = row.event
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
        .onChange(of: searchText) { applySearch() }
        .confirmationDialog("Delete the whole activity log?", isPresented: $isConfirmingClear) {
            Button("Clear log", role: .destructive) { Task { await clear() } }
        }
    }

    /// Filters once per search change or load, not on every redraw.
    private func applySearch() {
        let matchingRows =
            searchText.isEmpty
            ? rows
            : rows.filter {
                $0.event.summary.localizedCaseInsensitiveContains(searchText)
                    || $0.event.kind.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        matchingRowCount = matchingRows.count
        shownRows = Array(matchingRows.prefix(Self.maximumShownRows))
    }

    private func load() async {
        do {
            let oldestFirst = try await model.services.auditLog.readAllEvents()
            rows = oldestFirst.enumerated().reversed().map {
                LogRow(id: $0.offset, event: $0.element)
            }
            loadError = nil
            applySearch()
        } catch {
            loadError = "Could not read the log: \(error)"
        }
    }

    private func clear() async {
        do {
            try await model.services.auditLog.clear()
            rows = []
            applySearch()
        } catch {
            loadError = "Could not clear the log: \(error)"
        }
    }
}
