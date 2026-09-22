import Foundation

/// Runs `body` with a fresh temporary directory and removes it afterwards, even when `body`
/// throws.
func withTemporaryDirectory(_ body: (URL) async throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "GlimTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    do {
        try await body(directory)
    } catch {
        try FileManager.default.removeItem(at: directory)
        throw error
    }
    try FileManager.default.removeItem(at: directory)
}
