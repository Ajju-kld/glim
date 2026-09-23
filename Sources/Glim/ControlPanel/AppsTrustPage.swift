import AppKit
import GlimCore
import SwiftUI

/// Four columns — Never-touch, Read-only, Supervised, Full control. Drag an app to change its
/// tier; moving it to a more trusting column asks for Touch ID.
struct AppsTrustPage: View {
    private struct AppEntry: Identifiable, Hashable {
        let bundleIdentifier: String
        let name: String
        let bundleURL: URL?

        var id: String { bundleIdentifier }
    }

    @Environment(AppModel.self) private var model
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "Apps not listed are **\(model.settings.safetyPolicy.appTrust.defaultTier.displayName)**. Drag apps between columns. Making an app more trusted needs Touch ID."
            )
            .foregroundStyle(.secondary)
            TextField("Search apps", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
            HStack(alignment: .top, spacing: 12) {
                ForEach(TrustTier.allCases, id: \.self) { tier in
                    column(for: tier)
                }
            }
        }
        .task {
            installedApps = WorkspaceAppCatalog().installedApps()
        }
    }

    private func column(for tier: TrustTier) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tier.displayName).font(.headline)
                Spacer()
                TierBadge(tier: tier)
            }
            Text(description(of: tier))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            ForEach(entries(in: tier)) { entry in
                appRow(entry)
                    .draggable(entry.bundleIdentifier)
                    .contextMenu {
                        ForEach(TrustTier.allCases.filter { $0 != tier }, id: \.self) { otherTier in
                            Button("Move to \(otherTier.displayName)") {
                                move(entry.bundleIdentifier, to: otherTier)
                            }
                        }
                    }
            }
            Spacer(minLength: 24)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .panelSurface(cornerRadius: 16)
        .dropDestination(for: String.self) { bundleIdentifiers, _ in
            for bundleIdentifier in bundleIdentifiers {
                move(bundleIdentifier, to: tier)
            }
            return !bundleIdentifiers.isEmpty
        }
    }

    private func appRow(_ entry: AppEntry) -> some View {
        HStack(spacing: 8) {
            if let bundleURL = entry.bundleURL {
                Image(
                    nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path(percentEncoded: false))
                )
                .resizable()
                .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed").frame(width: 20, height: 20)
            }
            Text(entry.name).lineLimit(1)
        }
        .padding(.vertical, 2)
        .help(entry.bundleIdentifier)
    }

    private func entries(in tier: TrustTier) -> [AppEntry] {
        let trust = model.settings.safetyPolicy.appTrust
        let installedByIdentifier = Dictionary(
            installedApps.map { ($0.bundleIdentifier, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let listedIdentifiers = trust.tiersByBundleIdentifier.filter { $0.value == tier }.map(\.key)
        let unlistedInstalled =
            tier == trust.defaultTier
            ? installedApps.map(\.bundleIdentifier).filter {
                trust.tiersByBundleIdentifier[$0] == nil
            } : []
        return Set(listedIdentifiers + unlistedInstalled)
            .map { bundleIdentifier in
                AppEntry(
                    bundleIdentifier: bundleIdentifier,
                    name: installedByIdentifier[bundleIdentifier]?.name ?? bundleIdentifier,
                    bundleURL: installedByIdentifier[bundleIdentifier]?.url)
            }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func description(of tier: TrustTier) -> String {
        switch tier {
        case .neverTouch: "Can't be opened, read or moved."
        case .readOnly: "Open, read, move windows. No clicks or typing."
        case .supervised: "Clicks and typing, but every step asks you."
        case .fullControl: "Runs the approved plan; risky steps ask."
        }
    }

    private func move(_ bundleIdentifier: String, to tier: TrustTier) {
        model.changeSettings {
            $0.safetyPolicy.appTrust.tiersByBundleIdentifier[bundleIdentifier] = tier
        }
    }
}
