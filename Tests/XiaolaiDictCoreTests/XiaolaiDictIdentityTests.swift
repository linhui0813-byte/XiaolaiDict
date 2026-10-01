import Foundation
import XiaolaiDictBase
import XiaolaiDictCore
import Testing

/// The app finds its services, and each service admits the app, by identifiers compiled into both —
/// and the bundles declare theirs in Info.plist. A mismatch builds and signs cleanly, then fails
/// every lookup at run time; it is caught here instead.
struct XiaolaiDictIdentityTests {
    private func bundleIdentifier(in plist: String) throws -> String? {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Resources/\(plist)")
        let object = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return (object as? [String: Any])?["CFBundleIdentifier"] as? String
    }

    @Test func theAppsPlistDeclaresTheAppsIdentifier() throws {
        #if HUIDICT_LOCAL_BUILD
        #expect(XiaolaiDictIdentity.app == "com.linhui.huidict")
        #else
        #expect(try bundleIdentifier(in: "Info.plist") == XiaolaiDictIdentity.app)
        #endif
    }

    @Test func theServicesPlistDeclaresTheServicesIdentifier() throws {
        #if HUIDICT_LOCAL_BUILD
        #expect(XiaolaiDictIdentity.dictionaryService == "com.linhui.huidict.DictionaryService")
        #else
        #expect(try bundleIdentifier(in: "DictionaryService-Info.plist") == XiaolaiDictIdentity.dictionaryService)
        #endif
    }

    @Test func theModelServicesPlistDeclaresItsIdentifier() throws {
        #if HUIDICT_LOCAL_BUILD
        #expect(XiaolaiDictIdentity.modelService == "com.linhui.huidict.ModelService")
        #else
        #expect(try bundleIdentifier(in: "ModelService-Info.plist") == XiaolaiDictIdentity.modelService)
        #endif
    }
}
