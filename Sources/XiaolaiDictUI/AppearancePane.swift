import SwiftUI
import ImageIO

struct AppearancePane: View {
    var appearance: Appearance?

    var body: some View {
        Form {
            if let appearance {
                Bound(appearance: appearance)
            } else {
                Text("This pane is not connected to the reader's settings.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private struct Bound: View {
        @Bindable var appearance: Appearance
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Environment(\.scale) private var scale

        private var transparency: Binding<Double> {
            Binding(get: { appearance.lookupGlass.transparency }, set: {
                appearance.lookupGlass = LookupGlass(transparency: $0)
            })
        }

        var body: some View {
            Section {
                HStack(alignment: .top, spacing: scale.space.column) {
                    VStack(alignment: .leading, spacing: scale.space.stack) {
                        Text("Liquid Glass").font(.headline)
                        Text("Choose how much of the background shows through.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: Token.Glass.settingsLabelWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: scale.space.column) {
                        LookupGlassPreview()
                            .environment(\.lookupGlass, appearance.lookupGlass)
                            .environment(\.scale, .standard)
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text(appearance.lookupGlass.transparency,
                                 format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                        Slider(value: transparency, in: 0...1) { Text("Transparency") }
                            .labelsHidden()
                            .disabled(reduceTransparency)
                            .accessibilityIdentifier("lookup-glass-transparency")
                            .accessibilityValue(Text(appearance.lookupGlass.transparency,
                                                     format: .percent.precision(.fractionLength(0))))
                        HStack {
                            Text("More opaque")
                            Spacer()
                            Text("Clearer")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text("Text and icons stay crisp.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if reduceTransparency {
                            Text("Reduce Transparency is enabled in System Settings. The card uses an opaque background.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// A real compact lookup over sample reading text, so Settings previews the same surface as a lookup.
private struct LookupGlassPreview: View {
    @Environment(\.scale) private var scale
    @Environment(\.colorScheme) private var scheme
    @State private var cardFrame: CGRect = .zero
    @State private var previewImage: Data?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                readingPage
                CompactLookupCardView(card: Self.sample, onMore: {})
                    .frame(width: scale.space.lookupWidth)
                    .lookupGlassSurface()
                    .environment(\.liquefyGlassPreviewImage, previewImage)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("lookup-glass-preview")) } action: {
                        cardFrame = $0
                    }
                    .shadow(color: .black.opacity(Token.Opacity.cardLift),
                            radius: scale.shadow.panelRadius, y: scale.shadow.panelOffset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .coordinateSpace(name: "lookup-glass-preview")
            .task(id: SnapshotKey(size: geometry.size, frame: cardFrame, dark: scheme == .dark)) {
                guard cardFrame.width > 0, cardFrame.height > 0 else { return }
                let renderer = ImageRenderer(content: readingPage
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .environment(\.scale, scale).environment(\.colorScheme, scheme))
                renderer.scale = Token.Glass.previewRasterScale
                let crop = CGRect(x: cardFrame.minX * renderer.scale, y: cardFrame.minY * renderer.scale,
                                  width: cardFrame.width * renderer.scale, height: cardFrame.height * renderer.scale).integral
                guard let image = renderer.cgImage?.cropping(to: crop) else { return }
                let data = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return }
                CGImageDestinationAddImage(destination, image, nil)
                if CGImageDestinationFinalize(destination) { previewImage = data as Data }
            }
        }
        .frame(height: Token.Glass.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: scale.radius.panel, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lookup card preview")
    }

    private struct SnapshotKey: Equatable { let size: CGSize; let frame: CGRect; let dark: Bool }

    private var readingPage: some View {
        ZStack {
            CardSurface.panel(for: scheme)
            Color.accentColor.opacity(Token.Opacity.badgeWash)
            VStack(alignment: .leading, spacing: scale.space.column) {
                ForEach(0..<Token.Glass.previewParagraphs, id: \.self) { _ in
                    Text("The proposal was refused. We continued reading, looking for a clearer explanation. Each word opened another way to understand the story.")
                        .font(.system(size: scale.text.body, design: .serif))
                        .lineSpacing(scale.text.leading)
                }
            }
                .padding(scale.space.pad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(CardSurface.panel(for: scheme).opacity(Token.Opacity.accentBorder))
        }
    }

    private static var sample: LookupCard {
        let meanings = [("v.", "拒绝；回绝"), ("v.", "不接受；拒收"), ("adj.", "遭拒绝的，被拒绝的")]
        let senses = meanings.enumerated().map { index, meaning in
            SensePresentation(key: nil, ordinal: index + 1, partOfSpeech: meaning.0,
                              label: meaning.1, keyKind: .position,
                              standing: .confirmed(.reader), metBefore: false)
        }
        return LookupCard(term: "refused", heading: "refused", partOfSpeech: "v.",
                          pronunciation: "/rɪˈfjuːzd/", answer: .sense(senses[0]),
                          sentence: nil, alternatives: Array(senses.dropFirst()))
    }
}
