import GlimCore
import SwiftUI

/// A custom sidebar and page over a dark, glowing backdrop with translucent cards.
struct ControlPanelView: View {
    /// Tunable: sidebar width.
    private static let sidebarWidth: CGFloat = 232
    /// Tunable: widest a page's content grows.
    private static let maximumContentWidth: CGFloat = 860

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ControlPanelSidebar()
                .frame(width: Self.sidebarWidth)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader(page: model.selectedPage)
                    if let settingsMessage = model.settingsMessage {
                        Label(settingsMessage, systemImage: "info.circle.fill")
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .panelSurface(cornerRadius: 12, tint: .blue)
                    }
                    // Pages swap instantly: animating the swap laid out both pages at once
                    // and animated the scroll height, which made switching stutter.
                    page(for: model.selectedPage)
                }
                .padding(.horizontal, 32)
                .padding(.top, 44)
                .padding(.bottom, 32)
                .frame(maxWidth: Self.maximumContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
        }
        .background(PanelBackdrop())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func page(for page: ControlPanelPage) -> some View {
        switch page {
        case .dashboard: DashboardPage()
        case .appsTrust: AppsTrustPage()
        case .safetyRules: SafetyRulesPage()
        case .aiModels: AIModelsPage()
        case .screenGlow: ScreenGlowPage()
        case .permissions: PermissionsPage()
        case .activityLog: ActivityLogPage()
        case .layaTraining: LayaTrainingPage()
        }
    }
}

/// Glim's brand, its armed state, the pages, and a STOP that is always one click away.
private struct ControlPanelSidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                // Still: a moving orb this small isn't worth redrawing the window every frame.
                GlimOrbView(mood: model.isArmed ? .listening(level: 0.15) : .alert, isPaused: true)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Glim").font(.system(size: 17, weight: .semibold))
                    ArmedChip(isArmed: model.isArmed)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 6)
            VStack(spacing: 2) {
                ForEach(ControlPanelPage.allCases) { page in
                    SidebarRow(page: page, isSelected: model.selectedPage == page) {
                        model.selectedPage = page
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                model.stopEverything()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("Stop").fontWeight(.semibold)
                    Spacer()
                    Text(HotkeyCombo.killSwitch.displayName)
                        .font(.caption.monospaced())
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(.red.gradient, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop Glim")
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black.opacity(0.25))
        .overlay(alignment: .trailing) {
            Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
        }
    }
}

private struct SidebarRow: View {
    /// Tunable: how long the selection highlight takes to move.
    private static let highlightAnimation = Animation.smooth(duration: 0.15)

    let page: ControlPanelPage
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        isSelected
                            ? AnyShapeStyle(Color.accentColor.gradient)
                            : AnyShapeStyle(.white.opacity(0.06)),
                        in: .rect(cornerRadius: 7))
                Text(page.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                .white.opacity(isSelected ? 0.1 : (isHovered ? 0.05 : 0)),
                in: .rect(cornerRadius: 9)
            )
            .contentShape(.rect)
            .animation(Self.highlightAnimation, value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// "Armed" in green or "Stopped" in red.
struct ArmedChip: View {
    let isArmed: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(isArmed ? .green : .red).frame(width: 6, height: 6)
            Text(isArmed ? "Armed" : "Stopped")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isArmed ? .green : .red)
        }
    }
}

/// The page's large title and one line of explanation.
private struct PageHeader: View {
    let page: ControlPanelPage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(page.title).font(.system(size: 28, weight: .bold))
            Text(page.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

/// Deep indigo fading to black, with two soft glows in Glim's colors.
private struct PanelBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.06, blue: 0.16),
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            glow(
                Color(red: 0.3, green: 0.4, blue: 1.0).opacity(0.3), at: UnitPoint(x: 0.9, y: 0.05),
                radius: 520)
            glow(
                Color(red: 0.2, green: 0.9, blue: 1.0).opacity(0.14),
                at: UnitPoint(x: 0.1, y: 0.95), radius: 440)
        }
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, at center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [color, .clear], center: center, startRadius: 0, endRadius: radius)
    }
}

extension View {
    /// A translucent rounded card with a light top edge, lightly tinted when asked.
    func panelSurface(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return
            self
            .background {
                shape.fill(.white.opacity(0.045))
                if let tint {
                    shape.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.18), tint.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .white.opacity(0.04)], startPoint: .top,
                        endPoint: .bottom))
            )
    }
}

/// A card with a tinted icon badge and a title.
struct GlassCard<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(tint.gradient, in: .rect(cornerRadius: 7))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelSurface()
    }
}

/// A status line: coloured dot, name, and detail.
struct StatusRow: View {
    let name: String
    let detail: String
    let isHealthy: Bool?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isHealthy.map { $0 ? Color.green : Color.red } ?? Color.secondary)
                .frame(width: 8, height: 8)
                .shadow(color: isHealthy.map { $0 ? .green : .red } ?? .clear, radius: 3)
            Text(name)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
