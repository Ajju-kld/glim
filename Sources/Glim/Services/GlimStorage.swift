import Foundation

/// Where Glim keeps its own files: `~/Library/Application Support/Glim`.
enum GlimStorage {
    static var directory: URL {
        let applicationSupport =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(
                path: "Library/Application Support")
        return applicationSupport.appending(path: "Glim", directoryHint: .isDirectory)
    }

    static var settingsFileURL: URL {
        directory.appending(path: "settings.json", directoryHint: .notDirectory)
    }

    static var auditDirectory: URL {
        directory.appending(path: "Audit", directoryHint: .isDirectory)
    }
}
