import Foundation
import XiaolaiDictUI

/// Update verification uses the same silent probes as Settings, with a machine-readable result.
enum PermissionReport {
    @MainActor
    static func run(
        probe: () async -> PermissionsReport = { await .probe() },
        write: (String) -> Bool = LookupCommand.writeLine
    ) async -> CommandStatus {
        let report = await probe()
        var permissions = Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0.rawValue, "missing") })
        for state in report.states {
            permissions[state.permission.rawValue] = switch state.found {
            case .granted: "granted"
            case .declined: "declined"
            case .couldNotTell: "couldNotTell"
            }
        }
        let allGranted = Permission.allCases.allSatisfy { permissions[$0.rawValue] == "granted" }
        guard Instrument.write([
            "bundle": Bundle.main.bundleIdentifier ?? "none",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "none",
            "pid": ProcessInfo.processInfo.processIdentifier,
            "permissions": permissions,
            "allGranted": allGranted,
        ], to: write) else { return .internalError }
        return allGranted ? .success : .failure
    }
}
