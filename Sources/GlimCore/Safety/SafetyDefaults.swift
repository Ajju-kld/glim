/// The safe defaults agreed in the design (spec §7 and §9.4). Every list is editable in the
/// control panel; loosening any of them needs Touch ID.
enum SafetyDefaults {
    /// Business rule: destructive, financial, account and permission phrases.
    static let forbiddenPhrases = [
        "delete", "remove", "trash", "move to trash", "erase", "empty", "wipe", "format",
        "uninstall", "reset", "discard", "clear all", "clear history", "don't save", "replace",
        "overwrite", "revert",
        "buy", "pay", "purchase", "order", "checkout", "transfer", "subscribe", "unsubscribe",
        "cancel subscription",
        "sign out", "log out", "deactivate", "change password",
        "allow", "always allow", "install", "trust", "block",
    ]

    /// Business rule: phrases for actions that send, share or close something.
    static let confirmPhrases = [
        "send", "submit", "post", "share", "reply", "forward", "accept", "agree", "close",
    ]

    /// Business rule: apps Glim may not even open or read — secrets, remote access, money,
    /// system maintenance, security prompts, and Glim itself.
    static let neverTouchBundleIdentifiers = [
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.philandro.anydesk",
        "com.apple.ScreenContinuity",
        "net.metaquotes.wine.MetaTrader5",
        "com.titanium.OnyX",
        "com.apple.backup.launcher",
        "dev.straxs.Glim",
        "com.apple.SecurityAgent",
        "com.apple.coreservices.uiagent",
        "com.apple.UserNotificationCenter",
        "com.apple.universalAccessAuthWarn",
        "com.apple.loginwindow",
    ]

    /// Business rule: terminals, script runners, settings and browsers. Every unlisted app is
    /// read-only too; listing these documents the intent in the control panel.
    static let readOnlyBundleIdentifiers = [
        "com.apple.Terminal",
        "dev.warp.Warp-Stable",
        "com.googlecode.iterm2",
        "com.apple.ScriptEditor2",
        "com.apple.Automator",
        "com.apple.shortcuts",
        "com.apple.ActivityMonitor",
        "com.apple.systempreferences",
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "ai.perplexity.comet",
    ]

    /// Business rule: coding tools and AI agents — every step asks the person.
    static let supervisedBundleIdentifiers = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.apple.dt.Xcode",
        "com.google.android.studio",
        "com.google.antigravity",
        "ai.opencode.desktop",
        "com.postmanlabs.mac",
        "com.usebruno.app",
        "com.docker.docker",
        "com.anthropic.claudefordesktop",
        "com.openai.codex",
    ]

    /// Business rule: writing, office, media, messaging and the Testbed practice app.
    static let fullControlBundleIdentifiers = [
        "com.apple.Notes",
        "com.apple.TextEdit",
        "com.apple.Stickies",
        "com.apple.reminders",
        "com.apple.iWork.Pages",
        "com.apple.iCal",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Keynote",
        "com.apple.Preview",
        "com.apple.freeform",
        "com.apple.Music",
        "com.spotify.client",
        "com.apple.podcasts",
        "com.apple.TV",
        "com.apple.QuickTimePlayerX",
        "com.apple.mail",
        "com.apple.MobileSMS",
        "net.whatsapp.WhatsApp",
        "com.tinyspeck.slackmacgap",
        "dev.straxs.Glim.Testbed",
    ]

    /// All tier assignments. More restrictive lists are applied last, so if an app were ever
    /// listed twice the stricter tier would win.
    static var appTiers: [String: TrustTier] {
        var tiers: [String: TrustTier] = [:]
        for bundleIdentifier in fullControlBundleIdentifiers {
            tiers[bundleIdentifier] = .fullControl
        }
        for bundleIdentifier in supervisedBundleIdentifiers {
            tiers[bundleIdentifier] = .supervised
        }
        for bundleIdentifier in readOnlyBundleIdentifiers {
            tiers[bundleIdentifier] = .readOnly
        }
        for bundleIdentifier in neverTouchBundleIdentifiers {
            tiers[bundleIdentifier] = .neverTouch
        }
        return tiers
    }
}
