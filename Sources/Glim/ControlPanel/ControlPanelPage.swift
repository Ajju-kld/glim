/// The control panel's sidebar pages.
enum ControlPanelPage: String, CaseIterable, Identifiable {
    case dashboard
    case appsTrust
    case safetyRules
    case aiModels
    case screenGlow
    case permissions
    case activityLog
    case layaTraining

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .appsTrust: "Apps & Trust"
        case .safetyRules: "Safety Rules"
        case .aiModels: "AI Models"
        case .screenGlow: "Screen Glow"
        case .permissions: "Permissions"
        case .activityLog: "Activity Log"
        case .layaTraining: "Laya Training"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: "Status, health and today's tasks at a glance."
        case .appsTrust: "Decide how much Glim may do in each app."
        case .safetyRules: "Words that block or ask, limits, and approvals."
        case .aiModels: "The planner on this Mac and its second opinions."
        case .screenGlow: "Screen chat, and the colours of the glow around your screen."
        case .permissions: "What macOS lets Glim use. Glim never changes these itself."
        case .activityLog: "Everything Glim heard, planned, checked and did."
        case .layaTraining: "Review what Glim did, so Laya learns your Mac apps."
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .appsTrust: "square.grid.2x2"
        case .safetyRules: "shield.lefthalf.filled"
        case .aiModels: "cpu"
        case .screenGlow: "rectangle.dashed"
        case .permissions: "lock.shield"
        case .activityLog: "list.bullet.rectangle"
        case .layaTraining: "graduationcap"
        }
    }
}
