import Foundation

/// How long and how much audit history Glim keeps.
public struct AuditRetention: Sendable, Equatable {
    private static let secondsPerDay: TimeInterval = 86_400
    private static let bytesPerMegabyte = 1_048_576

    /// Business rules from the design (B-Q10): keep 7 days, at most 5 MB, in files of 1 MB.
    public static let standard = AuditRetention(
        maximumAge: 7 * secondsPerDay,
        maximumTotalBytes: 5 * bytesPerMegabyte,
        maximumBytesPerFile: bytesPerMegabyte)

    /// Files from days older than this are deleted.
    public let maximumAge: TimeInterval
    /// Oldest files are deleted until the total is at most this.
    public let maximumTotalBytes: Int
    /// A new file is started when the current one would grow past this.
    public let maximumBytesPerFile: Int

    /// Creates a retention policy.
    public init(maximumAge: TimeInterval, maximumTotalBytes: Int, maximumBytesPerFile: Int) {
        self.maximumAge = maximumAge
        self.maximumTotalBytes = maximumTotalBytes
        self.maximumBytesPerFile = maximumBytesPerFile
    }
}
