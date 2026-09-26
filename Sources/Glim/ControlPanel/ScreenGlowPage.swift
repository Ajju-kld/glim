import GlimCore
import SwiftUI

/// Screen chat and its glow: turn it on, pick the glow's colours, and see them live. Edits show
/// at once in the preview and are saved with the settings once the person stops adjusting, so
/// dragging a colour doesn't write the settings (and the Activity Log) dozens of times.
struct ScreenGlowPage: View {
    /// Tunable: the preview's size and how thin its glow is compared with the full screen.
    private static let previewSize = CGSize(width: 360, height: 210)
    private static let previewWidthScale: CGFloat = 0.3
    private static let previewCornerRadius: CGFloat = 14
    /// Tunable: how long after the last adjustment the chosen colours are saved.
    private static let saveDelay = Duration.milliseconds(600)

    @Environment(AppModel.self) private var model
    @State private var previewMood = PreviewMood.resting
    /// The theme being edited, shown in the preview right away.
    @State private var draftTheme = GlowTheme.standard
    @State private var pendingSave: Task<Void, Never>?

    /// Moods the preview can show, so each can be tried without speaking.
    enum PreviewMood: String, CaseIterable, Identifiable {
        case resting, listening, thinking

        var id: Self { self }

        var title: String {
            switch self {
            case .resting: "Waiting"
            case .listening: "Listening"
            case .thinking: "Thinking"
            }
        }

        var orbMood: OrbMood? {
            switch self {
            case .resting: nil
            case .listening: .listening(level: 0.7)
            case .thinking: .thinking
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard(title: "Screen chat", systemImage: "sparkles.rectangle.stack", tint: .purple)
            {
                Text(
                    "Hold \(HotkeyCombo.screenChat.displayName) and ask about anything on screen, or ask Glim to do something: the edges of your screen glow, your words show at the bottom, then Glim's answer. Hold \(HotkeyCombo.screenChat.displayName) again to follow up; Glim remembers the conversation. A minute of quiet ends it."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Text(
                    "Glim sees the whole screen while it glows, except apps set to Never touch, which are cut out of the picture before the AI sees it. Nothing is read while the glow is off."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Button(model.screenChat.isActive ? "End screen chat" : "Start screen chat") {
                    model.toggleScreenChat()
                }
                .disabled(!model.isArmed && !model.screenChat.isActive)
            }
            GlassCard(title: "Glow colours", systemImage: "paintpalette", tint: .pink) {
                Picker("Style", selection: styleBinding) {
                    ForEach(GlowStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                colourControls
                preview
                if draftTheme != .standard {
                    Button("Back to Glim's colours") {
                        draftTheme = .standard
                    }
                }
            }
        }
        .onAppear { draftTheme = model.settings.glowTheme }
        .onChange(of: draftTheme) { _, editedTheme in
            saveAfterAdjusting(editedTheme)
        }
    }

    @ViewBuilder private var colourControls: some View {
        let theme = draftTheme
        switch theme.style {
        case .orbColours:
            Text("The orb's own colours, changing as Glim listens, thinks and acts.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .rainbow:
            Text("A rainbow turning slowly around the screen.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .singleColour:
            ColorPicker("Colour", selection: singleColourBinding, supportsOpacity: false)
        case .custom:
            HStack(spacing: 12) {
                ForEach(theme.customColours.indices, id: \.self) { colourIndex in
                    HStack(spacing: 4) {
                        ColorPicker(
                            "Colour \(colourIndex + 1)",
                            selection: customColourBinding(at: colourIndex),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        if theme.customColours.count > GlowTheme.minimumCustomColours {
                            Button {
                                removeCustomColour(at: colourIndex)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove this colour")
                        }
                    }
                }
                if theme.customColours.count < GlowTheme.maximumCustomColours {
                    Button("Add colour", systemImage: "plus.circle") {
                        addCustomColour()
                    }
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Preview", selection: $previewMood) {
                ForEach(PreviewMood.allCases) { mood in
                    Text(mood.title).tag(mood)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            ZStack {
                RoundedRectangle(cornerRadius: Self.previewCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                EdgeGlowPreview(
                    appearance: EdgeGlowAppearance(theme: draftTheme, mood: previewMood.orbMood),
                    cornerRadius: Self.previewCornerRadius, widthScale: Self.previewWidthScale)
            }
            .frame(width: Self.previewSize.width, height: Self.previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: Self.previewCornerRadius, style: .continuous))
        }
    }

    // MARK: - Editing

    private var styleBinding: Binding<GlowStyle> {
        Binding(get: { draftTheme.style }, set: { draftTheme.style = $0 })
    }

    private var singleColourBinding: Binding<Color> {
        Binding(
            get: { Color(draftTheme.singleColour) },
            set: { newColor in
                guard let chosenColour = GlowColour(newColor) else { return }
                draftTheme.singleColour = chosenColour
            })
    }

    private func customColourBinding(at colourIndex: Int) -> Binding<Color> {
        Binding(
            get: {
                draftTheme.customColours.indices.contains(colourIndex)
                    ? Color(draftTheme.customColours[colourIndex]) : .white
            },
            set: { newColor in
                guard let chosenColour = GlowColour(newColor),
                    draftTheme.customColours.indices.contains(colourIndex)
                else { return }
                draftTheme.customColours[colourIndex] = chosenColour
            })
    }

    private func addCustomColour() {
        draftTheme.customColours.append(
            draftTheme.customColours.last ?? GlowTheme.standard.singleColour)
    }

    private func removeCustomColour(at colourIndex: Int) {
        guard draftTheme.customColours.indices.contains(colourIndex) else { return }
        draftTheme.customColours.remove(at: colourIndex)
    }

    // MARK: - Saving

    /// Saves `editedTheme` once no further adjustment arrives for a moment.
    private func saveAfterAdjusting(_ editedTheme: GlowTheme) {
        pendingSave?.cancel()
        guard editedTheme != model.settings.glowTheme else { return }
        pendingSave = Task {
            do {
                try await Task.sleep(for: Self.saveDelay)
            } catch {
                // A newer adjustment replaced this save.
                return
            }
            model.changeSettings { $0.glowTheme = editedTheme }
        }
    }
}
