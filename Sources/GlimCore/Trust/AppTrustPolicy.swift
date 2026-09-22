/// Which trust tier each app has, identified by bundle identifier.
///
/// Apps not listed get `defaultTier`, read-only by default, so new apps start with the least
/// power (default-deny).
public struct AppTrustPolicy: Sendable, Equatable, Codable {
    /// Business rule: an app whose code signature did not validate never gets more than this,
    /// so an impostor using a trusted bundle identifier gains nothing.
    public static let highestTierForUnverifiedApps = TrustTier.readOnly

    /// Tier assignments by bundle identifier.
    public var tiersByBundleIdentifier: [String: TrustTier]
    /// Tier for every app not listed.
    public var defaultTier: TrustTier

    /// Creates a policy.
    public init(tiersByBundleIdentifier: [String: TrustTier], defaultTier: TrustTier) {
        self.tiersByBundleIdentifier = tiersByBundleIdentifier
        self.defaultTier = defaultTier
    }

    /// The tier that applies to `app`, after capping apps whose signature did not validate.
    public func tier(for app: AppIdentity) -> TrustTier {
        let assignedTier = tiersByBundleIdentifier[app.bundleIdentifier] ?? defaultTier
        guard app.hasValidSignature else {
            return min(assignedTier, Self.highestTierForUnverifiedApps)
        }
        return assignedTier
    }

    /// What `tier` permits for `kind`, as specified in the design (§8.2).
    public static func permission(for kind: ActionKind, in tier: TrustTier) -> TierPermission {
        switch tier {
        case .neverTouch:
            return .denied
        case .readOnly:
            return readOnlyPermission(for: kind)
        case .supervised:
            return kind == .speak ? .allowed : .allowedWithConfirmation
        case .fullControl:
            return kind == .quitApp ? .allowedWithConfirmation : .allowed
        }
    }

    private static func readOnlyPermission(for kind: ActionKind) -> TierPermission {
        switch kind {
        case .openApp, .switchApp, .moveWindow, .minimizeWindow, .restoreWindow, .speak:
            .allowed
        case .quitApp:
            .allowedWithConfirmation
        case .click, .typeText, .pressKey, .scroll:
            .denied
        }
    }
}
