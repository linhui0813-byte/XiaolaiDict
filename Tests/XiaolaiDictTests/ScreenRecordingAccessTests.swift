import Foundation
import Synchronization
import Testing
import XiaolaiDictTestSupport

@testable import XiaolaiDict
@testable import XiaolaiDictUI

/// Capture retries must not reopen permission dialogs, even when lookups overlap.
struct ScreenRecordingAccessTests {
    private func access(
        _ found: PermissionProbe, grantedByAsking: Bool = false
    ) -> (ScreenRecordingAccess, Counter) {
        let counter = Counter()
        return (ScreenRecordingAccess(
            probe: { found },
            request: { counter.bump(); return grantedByAsking }), counter)
    }

    /// Checked `Sendable`, with a lock. It is read from the test and written from an `@Sendable`
    /// closure, and `@unchecked` asserted a safety nothing provided — harmless while every test
    /// awaits one call, and an unsafe contract for the next one that does not.
    final class Counter: Sendable {
        private let count = Mutex(0)
        var asks: Int { count.withLock { $0 } }
        func bump() { count.withLock { $0 += 1 } }
    }

    @Test func alreadyGrantedIsAllowedWithoutAsking() async {
        let (permission, counter) = access(.granted)
        #expect(await permission.ensure() == .granted)
        #expect(counter.asks == 0, "a granted permission must not raise a prompt")
    }

    @Test func aDeclinedPermissionAsksAndIsAllowedWhenTheReaderAgrees() async {
        let (permission, counter) = access(.declined, grantedByAsking: true)
        #expect(await permission.ensure() == .granted)
        #expect(counter.asks == 1)
    }

    /// A refusal that stays refused. The prompt appears once; afterwards macOS shows nothing and
    /// the reader has to be sent to Settings, which is why the refusal carries a location.
    @Test func aRefusalIsReportedRatherThanRetriedForever() async {
        let (permission, counter) = access(.declined, grantedByAsking: false)
        for _ in 0..<5 { #expect(await permission.ensure() == .declined) }
        #expect(counter.asks == 1)
    }

    @Test func concurrentLookupsShareOnePermissionRequest() async {
        let (permission, counter) = access(.declined)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 { group.addTask { _ = await permission.ensure() } }
        }
        #expect(counter.asks == 1)
    }

    @Test func grantingInSettingsIsDetectedWithoutASecondRequest() async {
        let found = Mutex(PermissionProbe.declined)
        let counter = Counter()
        let permission = ScreenRecordingAccess(probe: { found.withLock { $0 } },
                                               request: { counter.bump(); return false })
        #expect(await permission.ensure() == .declined)
        found.withLock { $0 = .granted }
        #expect(await permission.ensure() == .granted)
        #expect(counter.asks == 1)
    }

    /// **The regression.** A probe that could not tell is not a refusal, and asking the system about
    /// it raises a dialog that grants nothing — measured 2026-09-25 against a Mac whose grant had
    /// stood for three days and whose TCC rows the dialog left untouched.
    ///
    /// The assertion is the *count*, not the answer: returning `couldNotTell` while still prompting
    /// would satisfy a test that only read the result, and the prompt is the thing the reader saw.
    @Test func anUnreadableGrantNeverRaisesAPrompt() async {
        let (permission, counter) = access(.couldNotTell, grantedByAsking: true)
        #expect(await permission.ensure() == .couldNotTell)
        #expect(counter.asks == 0, "a probe that could not tell must not raise a system dialog")
    }

    /// **A hover the reader walked away from must not raise a dialog.** The prompt is a system
    /// window that appears attached to nothing they asked for, and — measured on 2026-09-25 — it
    /// can grant nothing, because the permission was already granted.
    ///
    /// The count is the assertion. Returning `.declined` while still prompting satisfies any test
    /// that reads only the result, and the prompt is the whole of what the reader sees.
    @Test func acancelledLookupNeverRaisesAPrompt() async {
        let (permission, counter) = access(.declined, grantedByAsking: true)
        let task = Task { await permission.ensure() }
        task.cancel()
        _ = await task.value
        #expect(counter.asks == 0, "an abandoned hover put a permission dialog on the screen")
    }

    /// And it must not be laundered into a grant either — the capture would then fail with a
    /// message about capture rather than about consent, which is the older defect this file opens
    /// by describing.
    @Test func anUnreadableGrantIsNotTreatedAsPermission() async {
        let (permission, _) = access(.couldNotTell)
        #expect(await permission.ensure() != .granted)
    }
}

struct ScreenRecordingLocationTests {
    /// macOS 27 renamed this list too, exactly as it renamed Accessibility's.
    @Test func macOS27NamesItScreenAndSystemAudioRecording() {
        #expect(PrivacySettings.screenRecordingLocation(majorVersion: 27)
                == "System Settings → Privacy & Security → Screen & System Audio Recording")
    }

    @Test func earlierMacOSNamesItScreenRecording() {
        #expect(PrivacySettings.screenRecordingLocation(majorVersion: 26)
                == "System Settings → Privacy & Security → Screen Recording")
    }

    /// The refusal has to say where to go, because after the first prompt there is no second one.
    @Test func theRefusalNamesTheList() {
        let message = RecognitionError.screenRecordingDenied.errorDescription ?? ""
        // The whole location, not two words that happen to appear in it. "Screen: open System
        // Settings" satisfied the old pair while naming neither the permission nor the path.
        #expect(message.contains(PrivacySettings.screenRecordingLocation))
    }

    /// The unreadable case must *not* name it. Sending a reader to a list where the switch is
    /// already on is how a transient failure turns into a support question.
    @Test func theUnreadableCaseSendsTheReaderNowhere() {
        let message = RecognitionError.screenRecordingUnreadable.errorDescription ?? ""
        #expect(!message.contains("System Settings"))
        #expect(!message.isEmpty, "a failure still has to say something")
    }
}

/// All status surfaces use one silent preflight, then verify a granted capture path.
/// Calling ScreenCaptureKit before that preflight can itself raise a system dialog.
struct ScreenRecordingProbeTests {
    private var sources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources")
    }

    @Test func theSilentPreflightHasOneOwner() throws {
        let (offenders, scanned) = try SourceScan.offenders(
            of: "CGPreflightScreenCaptureAccess", under: sources)

        // The positive control, and a floor this tree justifies rather than a round number: the
        // package ships well over a hundred Swift files across its four modules, so anything near
        // 100 means a subtree went unread. `SourceScan` throws on a traversal error, which is the
        // other half — this used to skip an unreadable directory in silence.
        #expect(scanned > 100, "scanned only \(scanned) files — the source walk is broken")
        #expect(offenders == ["Permissions.swift"], "all permission surfaces must share the same silent preflight")
    }

    @Test func anUngrantedStatusCheckNeverTouchesScreenCaptureKit() async {
        let captures = ScreenRecordingAccessTests.Counter()
        for _ in 0..<5 {
            let found = await Permission.screenRecordingProbe(preflight: { false }, capture: { captures.bump() })
            #expect(found == .declined)
        }
        #expect(captures.asks == 0)
    }

    @Test func aPositivePreflightIsStillVerifiedByTheCaptureAPI() async {
        let captures = ScreenRecordingAccessTests.Counter()
        let found = await Permission.screenRecordingProbe(preflight: { true }, capture: { captures.bump() })
        #expect(found == .granted)
        #expect(captures.asks == 1)
    }

    @Test func aCaptureFailureAfterPreflightDoesNotBecomeARefusal() async {
        let found = await Permission.screenRecordingProbe(preflight: { true }, capture: {
            throw NSError(domain: "CaptureFixture", code: 1)
        })
        #expect(found == .couldNotTell)
    }
}
