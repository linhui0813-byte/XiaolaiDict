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

/// Keep the foreground inside the native glass hierarchy. Only the neutral wash changes opacity.
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
        if reduceTransparency {
            content.clipShape(shape)
                .background(shape.fill(CardSurface.panel(for: scheme)))
                .overlay(shape.strokeBorder(
                    Color.primary.opacity(contrast == .increased
                        ? Token.Opacity.accentBorder : Token.Opacity.border),
                    lineWidth: Token.Stroke.hairline))
        } else {
            content.clipShape(shape)
                .background(shape.fill(CardSurface.panel(for: scheme).opacity(
                    glass.surfaceOpacity(reduceTransparency: false))))
                .glassEffect(.clear, in: shape)
                // This window must stay non-key. The environment changes visual activity only.
                .environment(\.appearsActive, true)
                .overlay {
                    LookupGlassRim(shape: shape, increasedContrast: contrast == .increased)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }
    }
}

/// An illuminated edge gives a large glass sheet visible thickness even over a uniform page.
/// The backdrop blur and refraction remain native; no background is captured or drawn here.
private struct LookupGlassRim: View {
    let shape: RoundedRectangle
    let increasedContrast: Bool

    var body: some View {
        ZStack {
            // Light just inside the edge, rather than a white wash across the reading surface.
            shape.inset(by: Token.Glass.rimInset)
                .strokeBorder(.white.opacity(Token.Glass.rimGlowOpacity), lineWidth: Token.Glass.rimGlowWidth)
                .blur(radius: Token.Glass.rimGlowRadius)
                .clipShape(shape)
            // The inner edge shades the lower side of the glass and catches light above it.
            shape.inset(by: Token.Glass.rimInset)
                .strokeBorder(LinearGradient(gradient: Token.Glass.innerReflection,
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: Token.Stroke.hairline)
                .blur(radius: increasedContrast ? 0 : Token.Glass.innerReflectionBlur)
            shape.strokeBorder(LinearGradient(gradient: Token.Glass.outerReflection,
                startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: Token.Glass.rimWidth)
            if increasedContrast {
                shape.inset(by: Token.Glass.contrastInset).strokeBorder(
                    Color.primary.opacity(Token.Opacity.accentBorder),
                    lineWidth: Token.Stroke.hairline)
            }
        }
    }
}

extension View {
    func lookupGlassSurface() -> some View { modifier(LookupGlassSurface()) }
}
