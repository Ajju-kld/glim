/// A size in whole pixels.
public struct PixelSize: Sendable, Equatable {
    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int

    /// Creates a pixel size.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
