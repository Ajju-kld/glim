import GlimCore
import SwiftUI

extension Color {
    /// The SwiftUI colour for a saved glow colour.
    init(_ glowColour: GlowColour) {
        self.init(red: glowColour.red, green: glowColour.green, blue: glowColour.blue)
    }
}

extension GlowColour {
    /// The saved colour for a colour picked in a colour well, in sRGB. Nil when the colour
    /// can't be expressed in sRGB (a pattern, for example).
    init?(_ color: Color) {
        guard let components = NSColor(color).usingColorSpace(.sRGB) else {
            return nil
        }
        self.init(
            red: Double(components.redComponent), green: Double(components.greenComponent),
            blue: Double(components.blueComponent))
    }
}
