/// Fixed window positions. Glim never moves windows to arbitrary coordinates.
public enum WindowPreset: String, Sendable, Codable, CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case fill
    case center

    /// Words shown in plans, such as "left half".
    public var displayName: String {
        switch self {
        case .leftHalf: "left half"
        case .rightHalf: "right half"
        case .topHalf: "top half"
        case .bottomHalf: "bottom half"
        case .fill: "full screen"
        case .center: "center"
        }
    }
}
