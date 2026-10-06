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
        reduceTransparency ? 1 : 1 - transparency * Token.Glass.tintTransmission
    }

    /// Tint alone cannot reveal reading text: the fixed native blur hides it even without tint.
    func materialOpacity(reduceTransparency: Bool) -> Double {
        reduceTransparency ? 0 : 1 - transparency * Token.Glass.clearTransmission
    }
}

extension EnvironmentValues {
    @Entry var lookupGlass: LookupGlass = .standard
}

/// Adjust the complete optical background independently from the solid foreground.
private struct LookupGlassSurface: ViewModifier {
    @Environment(\.scale) private var scale
    @Environment(\.lookupGlass) private var glass
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var liquefyReady = false
    @State private var darkBackdrop: Bool?

    private var foregroundScheme: ColorScheme {
        if liquefyReady, glass.transparency > Token.Glass.foregroundAdaptationThreshold, let darkBackdrop {
            return darkBackdrop ? .dark : .light
        }
        return scheme
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: scale.radius.lookup, style: .continuous)
    }

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.clipShape(shape)
                .environment(\.colorScheme, scheme)
                .background(shape.fill(CardSurface.panel(for: scheme)))
                .overlay(shape.strokeBorder(
                    Color.primary.opacity(contrast == .increased
                        ? Token.Opacity.accentBorder : Token.Opacity.border),
                    lineWidth: Token.Stroke.hairline))
        } else {
            content.clipShape(shape)
                .environment(\.colorScheme, foregroundScheme)
                // Local separation around glyphs helps at the clear end without fogging the plate.
                .shadow(color: CardSurface.panel(for: foregroundScheme).opacity(glass.transparency),
                        radius: Token.Glass.foregroundGlowRadius)
                .shadow(color: CardSurface.panel(for: foregroundScheme).opacity(glass.transparency),
                        radius: Token.Glass.foregroundEdgeRadius)
                .background {
                    ZStack {
                        ZStack {
                            shape.fill(.clear)
                                .glassEffect(.clear, in: shape)
                                .opacity(glass.materialOpacity(reduceTransparency: false))
                            shape.fill(CardSurface.panel(for: scheme).opacity(
                                glass.surfaceOpacity(reduceTransparency: false)))
                        }
                        .opacity(liquefyReady ? 0 : 1)
                        LiquefyGlassSurface(onReady: { liquefyReady = $0 }, onBackdropDark: { darkBackdrop = $0 })
                            .environment(\.colorScheme, foregroundScheme)
                            .opacity(liquefyReady ? 1 : 0)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .clipShape(shape)
                }
                // This window must stay non-key. The environment changes visual activity only.
                .environment(\.appearsActive, true)
                .overlay {
                    if !liquefyReady || contrast == .increased {
                        LookupGlassRim(shape: shape, increasedContrast: contrast == .increased)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        }
    }
}

/// Native fallback edge and the optional high-contrast outline over the Liquefy surface.
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
