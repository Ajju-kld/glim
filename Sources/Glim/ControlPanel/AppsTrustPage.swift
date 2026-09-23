import AppKit
import GlimCore
import SwiftUI

/// One searchable list of apps, each with a tier menu. Filter tabs narrow it to one tier.
/// Making an app more trusted asks for Touch ID; making it less trusted applies at once.
struct AppsTrustPage: View {
    private struct AppEntry: Identifiable, Hashable {
        let bundleIdentifier: String
        let name: String
        let bundleURL: URL?
        let tier: TrustTier
        /// Whether the tier comes from the default rather than a choice for this app.
        let usesDefaultTier: Bool

        var id: String { bundleIdentifier }
    }

    /// Which apps the list shows.
    private enum Filter: Hashable {
        case all
        case tier(TrustTier)
    }

    /// Tunable: the icon size in each row.
    private static let iconSize: CGFloat = 22
    /// Tunable: the tier menu's width, so every row lines up.
    private static let tierMenuWidth: CGFloat = 150

    @Environment(AppModel.self) private var model
    @State private var searchText = ""
    @State private var filter = Filter.all

    var body: some View {
        let entries = allEntries
        VStack(alignment: .leading, spacing: 14) {
            Text(
                "Pick a tier for any app. Apps you haven't set are **\(model.settings.safetyPolicy.appTrust.defaultTier.displayName)**. Giving an app more trust needs Touch ID."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            ReadCheckSection()
            filterBar(entries: entries)
            TextField("Search apps", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
            let shownEntries = visible(entries)
            LazyVStack(spacing: 0) {
                if shownEntries.isEmpty {
                    Text("No apps match.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                }
                ForEach(shownEntries) { entry in
                    row(for: entry)
                    if entry.id != shownEntries.last?.id {
                        Divider().opacity(0.35).padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 6)
            .panelSurface(cornerRadius: 16)
            if case .tier(let tier) = filter {
                Text(description(of: tier))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await model.refreshInstalledApps() }
    }

    // MARK: - Filter

    private func filterBar(entries: [AppEntry]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all, title: "All", count: entries.count, color: .accentColor)
                ForEach(TrustTier.allCases, id: \.self) { tier in
                    filterChip(
                        .tier(tier), title: tier.displayName,
                        count: entries.filter { $0.tier == tier }.count,
                        color: PanelStyle.color(for: tier))
                }
            }
        }
    }

    private func filterChip(_ chipFilter: Filter, title: String, count: Int, color: Color)
        -> some View
    {
        let isSelected = filter == chipFilter
        return Button {
            filter = chipFilter
        } label: {
            HStack(spacing: 6) {
                Text(title).fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.12), in: .capsule)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .secondary)
            .background(isSelected ? color.opacity(0.35) : .white.opacity(0.06), in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.6) : .clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rows

    private func row(for entry: AppEntry) -> some View {
        HStack(spacing: 12) {
            appIcon(for: entry)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).lineLimit(1)
                if entry.name == entry.bundleIdentifier || entry.usesDefaultTier {
                    Text(entry.usesDefaultTier ? "Default tier" : "Not installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .help(entry.bundleIdentifier)
            Spacer(minLength: 8)
            tierMenu(for: entry)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func appIcon(for entry: AppEntry) -> some View {
        if let bundleURL = entry.bundleURL,
            let icon = model.appIconsByPath[bundleURL.path(percentEncoded: false)]
        {
            Image(nsImage: icon)
                .resizable()
                .frame(width: Self.iconSize, height: Self.iconSize)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .frame(width: Self.iconSize, height: Self.iconSize)
        }
    }

    private func tierMenu(for entry: AppEntry) -> some View {
        Menu {
            ForEach(TrustTier.allCases, id: \.self) { tier in
                Button {
                    move(entry.bundleIdentifier, to: tier)
                } label: {
                    if tier == entry.tier {
                        Label(tier.displayName, systemImage: "checkmark")
                    } else {
                        Text(tier.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(PanelStyle.color(for: entry.tier)).frame(width: 7, height: 7)
                Text(entry.tier.displayName).font(.callout)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(width: Self.tierMenuWidth)
            .background(PanelStyle.color(for: entry.tier).opacity(0.14), in: .capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Tier for \(entry.name)")
    }

    // MARK: - Data

    private var allEntries: [AppEntry] {
        let trust = model.settings.safetyPolicy.appTrust
        let installedApps = model.installedApps
        let installedByIdentifier = Dictionary(
            installedApps.map { ($0.bundleIdentifier, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let bundleIdentifiers = Set(installedApps.map(\.bundleIdentifier))
            .union(trust.tiersByBundleIdentifier.keys)
        return bundleIdentifiers.map { bundleIdentifier in
            let chosenTier = trust.tiersByBundleIdentifier[bundleIdentifier]
            return AppEntry(
                bundleIdentifier: bundleIdentifier,
                name: installedByIdentifier[bundleIdentifier]?.name ?? bundleIdentifier,
                bundleURL: installedByIdentifier[bundleIdentifier]?.url,
                tier: chosenTier ?? trust.defaultTier,
                usesDefaultTier: chosenTier == nil)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func visible(_ entries: [AppEntry]) -> [AppEntry] {
        entries.filter { entry in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .tier(let tier): matchesFilter = entry.tier == tier
            }
            let matchesSearch =
                searchText.isEmpty || entry.name.localizedCaseInsensitiveContains(searchText)
                || entry.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    private func description(of tier: TrustTier) -> String {
        switch tier {
        case .neverTouch: "Never-touch: Glim can't open, read or move these apps."
        case .readOnly: "Read-only: open, read and move windows. No clicks or typing."
        case .supervised: "Supervised: clicks and typing, but every step asks you."
        case .fullControl: "Full control: runs the plan; only dangerous steps ask."
        }
    }

    private func move(_ bundleIdentifier: String, to tier: TrustTier) {
        model.changeSettings {
            $0.safetyPolicy.appTrust.tiersByBundleIdentifier[bundleIdentifier] = tier
        }
    }
}
