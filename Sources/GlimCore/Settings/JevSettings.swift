/// The person's choices for the optional Jev cloud checker.
public struct JevSettings: Sendable, Equatable, Codable {
    /// Business rule (B-Q16): Jev is off by default, and messaging apps are never sent to it.
    public static let safeDefaults = JevSettings(
        isEnabled: false,
        excludedBundleIdentifiers: [
            "com.apple.mail", "com.apple.MobileSMS", "net.whatsapp.WhatsApp",
            "com.tinyspeck.slackmacgap",
        ])

    /// Whether Jev may be called at all.
    public var isEnabled: Bool
    /// Apps whose labels are never sent to Jev.
    public var excludedBundleIdentifiers: Set<String>

    /// Creates Jev settings.
    public init(isEnabled: Bool, excludedBundleIdentifiers: Set<String>) {
        self.isEnabled = isEnabled
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
    }
}
