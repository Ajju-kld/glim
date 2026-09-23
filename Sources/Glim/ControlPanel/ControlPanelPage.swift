/// The control panel's sidebar pages.
enum ControlPanelPage: String, CaseIterable, Identifiable {
    case dashboard
    case appsTrust
    case safetyRules
    case aiModels
    case permissions
    case activityLog

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .appsTrust: "Apps & Trust"
        case .safetyRules: "Safety Rules"
        case .aiModels: "AI Models"
        case .permissions: "Permissions"
        case .activityLog: "Activity Log"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .appsTrust: "square.grid.2x2"
        case .safetyRules: "shield.lefthalf.filled"
        case .aiModels: "cpu"
        case .permissions: "lock.shield"
        case .activityLog: "list.bullet.rectangle"
        }
    }
}
