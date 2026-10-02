import Foundation
import XiaolaiDictBase
import XiaolaiDictCore
import Testing

/// The app finds its services, and each service admits the app, by identifiers compiled into both —
/// and the bundles declare theirs in Info.plist. A mismatch builds and signs cleanly, then fails
/// every lookup at run time; it is caught here instead.
struct XiaolaiDictIdentityTests {
    private var repository: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func bundleIdentifier(in plist: String) throws -> String? {
        let url = repository.appending(path: "Resources/\(plist)")
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

    #if HUIDICT_LOCAL_BUILD
    /// The local plists are generated from the builder's declarations, independently of these
    /// compiled constants. Read the declarations rather than a possibly stale build snapshot.
    @Test func theLocalBundleBuilderUsesTheCompiledIdentifiers() throws {
        let script = try String(contentsOf: repository.appending(path: "Tools/build-bundle.sh"), encoding: .utf8)
        let declaration = try Regex(#"(?m)^\s*1\)[^\n]*\bBUNDLE_ID=([^;\s]+)"#)
        let match = try #require(try declaration.firstMatch(in: script), "the local build identifier was not found")
        let app = String(try #require(match.output[1].substring))
        #expect(app == XiaolaiDictIdentity.app)
        for (variable, expected) in [("SERVICE_ID", XiaolaiDictIdentity.dictionaryService),
                                     ("MODEL_SERVICE_ID", XiaolaiDictIdentity.modelService)] {
            let expression = try Regex("(?m)^readonly \(variable)=([^\\n]+)$")
            let declared = try #require(try expression.firstMatch(in: script), "\(variable) was not found")
            let value = String(try #require(declared.output[1].substring))
                .replacingOccurrences(of: "${BUNDLE_ID}", with: app)
                .replacingOccurrences(of: "$BUNDLE_ID", with: app)
            #expect(value == expected, "the builder and compiled code disagree about \(variable)")
        }
    }
    #endif
}
