/// A colour as red, green and blue from 0 to 1, saved with the settings. Channels outside that
/// range are clamped, so a damaged value can't produce an invalid colour.
public struct GlowColour: Sendable, Equatable, Hashable, Codable {
    /// The red channel, 0…1.
    public let red: Double
    /// The green channel, 0…1.
    public let green: Double
    /// The blue channel, 0…1.
    public let blue: Double

    /// Creates a colour, clamping each channel to 0…1.
    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamped(red)
        self.green = Self.clamped(green)
        self.blue = Self.clamped(blue)
    }

    private enum CodingKeys: String, CodingKey {
        case red, green, blue
    }

    /// Reads a saved colour, clamping its channels.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue))
    }

    private static func clamped(_ channel: Double) -> Double {
        guard channel.isFinite else {
            return 0
        }
        return min(max(channel, 0), 1)
    }
}
