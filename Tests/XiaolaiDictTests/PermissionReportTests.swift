import Foundation
import Testing
import XiaolaiDictUI
@testable import XiaolaiDict

@MainActor
struct PermissionReportTests {
    @Test func anUnreadablePermissionDoesNotClaimItIsOff() {
        let report = PermissionsReport(states: Permission.allCases.map {
            PermissionState(permission: $0, found: .couldNotTell)
        })
        #expect(!report.allGranted)
        #expect(report.menuWarning == nil)
    }

    @Test(arguments: Permission.allCases)
    func onlyAnExplicitRefusalIsNamedInAMixedReport(permission: Permission) throws {
        let report = PermissionsReport(states: Permission.allCases.map {
            PermissionState(permission: $0, found: $0 == permission ? .declined : .couldNotTell)
        })
        let warning = try #require(report.menuWarning)
        #expect(warning.contains(permission.name))
        for unknown in Permission.allCases where unknown != permission {
            #expect(!warning.contains(unknown.name))
        }
    }

    @Test func commandAcceptsNoExtraArguments() {
        #expect(LaunchArguments.parse(["--permission-report"]) == .success(.permissionReport))
        #expect(throws: (any Error).self) {
            try LaunchArguments.parse(["--permission-report", "--request"]).get()
        }
    }

    @Test(arguments: [PermissionProbe.declined, .couldNotTell])
    func ungrantedOrUnknownAccessMakesTheDiagnosticFail(found: PermissionProbe) async throws {
        var output = ""
        let status = await PermissionReport.run(probe: {
            PermissionsReport(states: [PermissionState(permission: .accessibility, found: .granted),
                                       PermissionState(permission: .screenRecording, found: found)])
        }, write: { output = $0; return true })
        #expect(status == .failure)
        let result = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        #expect(result["allGranted"] as? Bool == false)
        let permissions = try #require(result["permissions"] as? [String: String])
        #expect(permissions["screenRecording"] == (found == .declined ? "declined" : "couldNotTell"))
    }

    @Test func anIncompleteProbeCannotReportSuccess() async {
        let status = await PermissionReport.run(probe: { PermissionsReport(states: []) }, write: { _ in true })
        #expect(status == .failure)
    }

    @Test func bothGrantsSucceedAndAnUnwrittenReportFails() async {
        let granted = PermissionsReport(states: Permission.allCases.map {
            PermissionState(permission: $0, found: .granted)
        })
        #expect(await PermissionReport.run(probe: { granted }, write: { _ in true }) == .success)
        #expect(await PermissionReport.run(probe: { granted }, write: { _ in false }) == .internalError)
    }
}
