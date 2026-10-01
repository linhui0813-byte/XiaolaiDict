import Foundation
import LightweightCodeRequirements
import Security
import XiaolaiDictBase
import XPC

/// Local builds have no signing team. Pin the exact signed code in the hosting bundle instead:
/// sharing a user account or copying a bundle identifier does not authorize a different binary.
public enum ServicePeer {
    public static func appRequirement(serviceBundle: Bundle = .main) throws -> XPCPeerRequirement {
        #if HUIDICT_LOCAL_BUILD
        let app = try hostingApp(for: serviceBundle.bundleURL)
        return try requirement(at: app, identifier: XiaolaiDictIdentity.app)
        #else
        return .isFromSameTeam(andMatchesSigningIdentifier: XiaolaiDictIdentity.app)
        #endif
    }

    public static func serviceRequirement(identifier: String, appBundle: Bundle = .main) throws -> XPCPeerRequirement {
        #if HUIDICT_LOCAL_BUILD
        let name: String
        switch identifier {
        case XiaolaiDictIdentity.dictionaryService: name = "XiaolaiDictService"
        case XiaolaiDictIdentity.modelService: name = "XiaolaiDictModelService"
        default: throw TrustError.unexpectedBundle
        }
        guard appBundle.bundleIdentifier == XiaolaiDictIdentity.app else { throw TrustError.unexpectedBundle }
        return try requirement(
            at: appBundle.bundleURL.appending(path: "Contents/XPCServices/\(name).xpc"),
            identifier: identifier)
        #else
        return .isFromSameTeam(andMatchesSigningIdentifier: identifier)
        #endif
    }

    enum TrustError: Error {
        case unexpectedBundle
        case invalidSignature(OSStatus)
        case missingCodeHash
    }

    static func hostingApp(for service: URL) throws -> URL {
        let services = service.deletingLastPathComponent()
        let contents = services.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard service.pathExtension == "xpc", services.lastPathComponent == "XPCServices",
              contents.lastPathComponent == "Contents", app.pathExtension == "app",
              Bundle(url: app)?.bundleIdentifier == XiaolaiDictIdentity.app else {
            throw TrustError.unexpectedBundle
        }
        return app
    }

    static func requirement(at url: URL, identifier: String) throws -> XPCPeerRequirement {
        let hash = try codeHash(at: url, identifier: identifier)
        return .codeRequirement(try ProcessCodeRequirement.allOf {
            CodeDirectoryHash(hash)
            SigningIdentifier(identifier)
        })
    }

    /// Check the resource seal, including nested code, before trusting a hash from disk.
    /// Errors propagate: an unsigned or modified bundle never falls back to unrestricted XPC.
    static func codeHash(at url: URL, identifier: String) throws -> Data {
        var code: SecStaticCode?
        var status = SecStaticCodeCreateWithPath(url as CFURL, [], &code)
        guard status == errSecSuccess, let code else { throw TrustError.invalidSignature(status) }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        status = SecStaticCodeCheckValidity(code, flags, nil)
        guard status == errSecSuccess else { throw TrustError.invalidSignature(status) }
        var information: CFDictionary?
        status = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
        guard status == errSecSuccess, let information else { throw TrustError.invalidSignature(status) }
        let values = information as NSDictionary
        guard values[kSecCodeInfoIdentifier] as? String == identifier else { throw TrustError.unexpectedBundle }
        guard let hash = values[kSecCodeInfoUnique] as? Data, !hash.isEmpty else { throw TrustError.missingCodeHash }
        return hash
    }
}
