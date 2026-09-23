import SwiftUI

/// Sidebar + page, in the style of System Settings.
struct ControlPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(ControlPanelPage.allCases, selection: $model.selectedPage) { page in
                Label(page.title, systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let settingsMessage = model.settingsMessage {
                        Label(settingsMessage, systemImage: "info.circle.fill")
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                    page(for: model.selectedPage)
                }
                .padding(24)
                .frame(maxWidth: 820, alignment: .leading)
            }
            .navigationTitle(model.selectedPage.title)
        }
    }

    @ViewBuilder
    private func page(for page: ControlPanelPage) -> some View {
        switch page {
        case .dashboard: DashboardPage()
        case .appsTrust: AppsTrustPage()
        case .safetyRules: SafetyRulesPage()
        case .aiModels: AIModelsPage()
        case .permissions: PermissionsPage()
        case .activityLog: ActivityLogPage()
        }
    }
}

/// A rounded Liquid Glass card with a title.
struct GlassCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

/// A status line: coloured dot, name, and detail.
struct StatusRow: View {
    let name: String
    let detail: String
    let isHealthy: Bool?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isHealthy.map { $0 ? Color.green : Color.red } ?? Color.secondary)
                .frame(width: 8, height: 8)
            Text(name)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
