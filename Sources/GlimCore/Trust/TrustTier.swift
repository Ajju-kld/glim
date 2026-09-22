/// How much Glim may do inside an app, from most to least restrictive.
public enum TrustTier: String, Sendable, Codable, CaseIterable, Comparable {
    /// Glim can't open, read, move or act on the app.
    case neverTouch
    /// Glim can open, switch to, read, move and minimize the app, but never click or type in it.
    case readOnly
    /// Glim can click and type, but every step waits for the person's click.
    case supervised
    /// Glim runs the approved plan; only risky steps wait for the person's click.
    case fullControl

    /// Position from most restrictive (0) to least restrictive. Moving up loosens safety.
    public var permissiveness: Int {
        switch self {
        case .neverTouch: 0
        case .readOnly: 1
        case .supervised: 2
        case .fullControl: 3
        }
    }

    /// Name shown in the control panel and on plan badges.
    public var displayName: String {
        switch self {
        case .neverTouch: "Never-touch"
        case .readOnly: "Read-only"
        case .supervised: "Supervised"
        case .fullControl: "Full control"
        }
    }

    /// Orders tiers from most to least restrictive.
    public static func < (lhs: TrustTier, rhs: TrustTier) -> Bool {
        lhs.permissiveness < rhs.permissiveness
    }
}
