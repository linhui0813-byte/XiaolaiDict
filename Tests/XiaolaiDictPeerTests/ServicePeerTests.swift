import Foundation
import LightweightCodeRequirements
import Security
import Testing
import XiaolaiDictBase
import XiaolaiDictTestSupport
import XPC
@testable import XiaolaiDictPeer

struct ServicePeerTests {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = TemporaryDirectory(named: "xiaolaidict-peer")
        let app = root.appending("Fixture.app")
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents.appending(path: "MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appending(path: "Resources"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(filePath: "/usr/bin/true"), to: contents.appending(path: "MacOS/Fixture"))
        let plist = ["CFBundleIdentifier": XiaolaiDictIdentity.app, "CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))
        try Data("sealed resource".utf8).write(to: contents.appending(path: "Resources/meaning.txt"))
        try withExtendedLifetime(root) { try body(app) }
    }

    private func sign(_ app: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", "--options", "runtime", "--timestamp=none", app.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func signedLocalBundleProducesPeerRequirement() throws {
        try fixture { app in
            try sign(app)
            #expect(try !ServicePeer.codeHash(at: app, identifier: XiaolaiDictIdentity.app).isEmpty)
            _ = try ServicePeer.requirement(at: app, identifier: XiaolaiDictIdentity.app)
        }
    }

    @Test func alteredResourceIsRefused() throws {
        try fixture { app in
            try sign(app)
            try Data("changed".utf8).write(to: app.appending(path: "Contents/Resources/meaning.txt"))
            #expect(throws: (any Error).self) {
                try ServicePeer.requirement(at: app, identifier: XiaolaiDictIdentity.app)
            }
        }
    }

    @Test func wrongSigningIdentifierIsRefused() throws {
        try fixture { app in
            try sign(app)
            #expect(throws: (any Error).self) {
                try ServicePeer.requirement(at: app, identifier: "com.example.impostor")
            }
        }
    }

    @Test func unsignedBundleIsRefused() throws {
        try fixture { app in
            #expect(throws: (any Error).self) {
                try ServicePeer.requirement(at: app, identifier: XiaolaiDictIdentity.app)
            }
        }
    }

    @Test func serviceMustBeInsideExpectedHostApp() throws {
        try fixture { app in
            let nested = app.appending(path: "Contents/XPCServices/XiaolaiDictService.xpc")
            let host = try ServicePeer.hostingApp(for: nested)
            #expect(host.path == app.path)
            #expect(throws: (any Error).self) {
                try ServicePeer.hostingApp(for: app.appending(path: "Resources/XiaolaiDictService.xpc"))
            }
        }
    }

    private struct Echo: XPCPeerHandler {
        func handleIncomingRequest(_ input: String) -> (any Encodable)? { input }
    }

    /// Exercise macOS's peer check, including the hash rather than just the identifier.
    @Test(arguments: ["valid", "wrongHash", "wrongIdentifier"])
    func actualXPCPeerAuthentication(_ scenario: String) throws {
        var running: SecCode?
        #expect(SecCodeCopySelf([], &running) == errSecSuccess)
        let code = try #require(running)
        var staticCode: SecStaticCode?
        #expect(SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess)
        let signedCode = try #require(staticCode)
        var info: CFDictionary?
        #expect(SecCodeCopySigningInformation(signedCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess)
        let values = try #require(info) as NSDictionary
        let identifier = try #require(values[kSecCodeInfoIdentifier] as? String)
        let hash = try #require(values[kSecCodeInfoUnique] as? Data)
        let requirement = XPCPeerRequirement.codeRequirement(try ProcessCodeRequirement.allOf {
            CodeDirectoryHash(scenario == "wrongHash" ? Data(repeating: 0, count: hash.count) : hash)
            SigningIdentifier(scenario == "wrongIdentifier" ? "com.example.impostor" : identifier)
        })
        let listener = XPCListener { request in
            request.accept { session in
                session.setPeerRequirement(requirement)
                return Echo()
            }
        }
        defer { listener.cancel() }
        let session = try XPCSession(endpoint: listener.endpoint)
        defer { session.cancel(reason: "test complete") }
        if scenario == "valid" {
            let reply: String = try session.sendSync("ping")
            #expect(reply == "ping")
        } else {
            #expect(throws: (any Error).self) {
                let _: String = try session.sendSync("ping")
            }
        }
    }
}
