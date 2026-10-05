import Foundation
import Testing
import XiaolaiDictTestSupport
@testable import XiaolaiDictUI

@MainActor
struct LookupGlassTests {
    @Test func aNewInstallUsesTheSelectedBalancedGlass() {
        let appearance = Appearance(store: AppearanceStore(defaults: TemporaryDefaults.suite()))
        #expect(appearance.lookupGlass.transparency == 0.55)
    }

    @Test func sliderChangesSurviveRelaunchWithoutChangingDrawerGlass() {
        let defaults = TemporaryDefaults.suite()
        let appearance = Appearance(store: AppearanceStore(defaults: defaults))
        appearance.drawerGlass = .clear
        for value in [0.0, 0.23, 0.55, 0.87, 1.0] {
            appearance.lookupGlass = LookupGlass(transparency: value)
            let relaunched = Appearance(store: AppearanceStore(defaults: defaults))
            #expect(relaunched.lookupGlass.transparency == value)
            #expect(relaunched.drawerGlass == .clear)
        }
    }

    @Test func invalidPreferencesCannotCreateAnInvalidSurface() {
        let defaults = TemporaryDefaults.suite()
        let store = AppearanceStore(defaults: defaults)
        defaults.set("invalid", forKey: AppearanceStore.lookupGlassKey)
        #expect(store.loadLookupGlass() == .standard)
        #expect(LookupGlass(transparency: -.infinity) == .standard)
        #expect(LookupGlass(transparency: .nan) == .standard)
        #expect(LookupGlass(transparency: -5).transparency == 0)
        #expect(LookupGlass(transparency: 5).transparency == 1)
    }

    @Test func transparencyAffectsTheSurfaceContinuouslyAndRespectsAccessibility() {
        for value in [0.0, 0.25, 0.55, 0.75, 1.0] {
            let glass = LookupGlass(transparency: value)
            #expect(glass.surfaceOpacity(reduceTransparency: false) == 1 - value)
            #expect(glass.surfaceOpacity(reduceTransparency: true) == 1)
        }
    }
}
