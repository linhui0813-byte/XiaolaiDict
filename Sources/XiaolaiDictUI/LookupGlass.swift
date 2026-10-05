import SwiftUI

/// The amount of background visible through a lookup card, independent of its text and controls.
public struct LookupGlass: Equatable, Sendable {
    public static let standard = LookupGlass(transparency: Token.Glass.transparency)
    public let transparency: Double

    public init(transparency: Double) {
        self.transparency = transparency.isFinite
            ? min(max(transparency, 0), 1) : Token.Glass.transparency
    }

    func surfaceOpacity(reduceTransparency: Bool) -> Double {
        reduceTransparency ? 1 : 1 - transparency
    }
}

extension EnvironmentValues {
    @Entry var lookupGlass: LookupGlass = .standard
}

/// Only the background receives the glass effect. Fading the whole card would also fade its text.
private struct LookupGlassSurface: ViewModifier {
    @Environment(\.scale) private var scale
    @Environment(\.lookupGlass) private var glass
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: scale.radius.lookup, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .clipShape(shape)
            .background {
                if reduceTransparency {
                    shape.fill(CardSurface.panel(for: scheme))
                } else {
                    // A continuous wash controls opacity while native clear glass keeps its rim
                    // and refraction. No private blur API and no fading of the foreground.
                    shape.fill(CardSurface.panel(for: scheme).opacity(
                        glass.surfaceOpacity(reduceTransparency: false)))
                        .glassEffect(.clear, in: shape)
                        // The lookup deliberately never becomes key. Keep only its material
                        // visually active; making the window key would steal the reader's focus.
                        .environment(\.appearsActive, true)
                }
            }
            .overlay(shape.strokeBorder(
                Color.primary.opacity(contrast == .increased
                    ? Token.Opacity.accentBorder : Token.Opacity.border),
                lineWidth: Token.Stroke.hairline))
    }
}

extension View {
    func lookupGlassSurface() -> some View { modifier(LookupGlassSurface()) }
}
