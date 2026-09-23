import SwiftUI

/// The pill's outline. Under a notch, its top edge is flush with the screen and curves out into
/// small concave shoulders, so it reads as the notch itself growing. Without a notch it is a
/// floating rounded pill.
struct NotchPillShape: Shape {
    /// Tunable: width and height of each concave shoulder beside the notch.
    static let shoulderSize: CGFloat = 8

    var bottomCornerRadius: CGFloat
    let mergesWithNotch: Bool

    var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard mergesWithNotch else {
            return Path(roundedRect: rect, cornerRadius: bottomCornerRadius, style: .continuous)
        }
        let shoulder = min(Self.shoulderSize, rect.width / 4, rect.height / 2)
        let bodyLeft = rect.minX + shoulder
        let bodyRight = rect.maxX - shoulder
        let radius = min(bottomCornerRadius, (bodyRight - bodyLeft) / 2, rect.height - shoulder)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bodyLeft, y: rect.minY + shoulder),
            control: CGPoint(x: bodyLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: bodyLeft, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: bodyLeft + radius, y: rect.maxY),
            control: CGPoint(x: bodyLeft, y: rect.maxY))
        path.addLine(to: CGPoint(x: bodyRight - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: bodyRight, y: rect.maxY - radius),
            control: CGPoint(x: bodyRight, y: rect.maxY))
        path.addLine(to: CGPoint(x: bodyRight, y: rect.minY + shoulder))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: bodyRight, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
