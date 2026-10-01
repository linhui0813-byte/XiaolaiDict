import Synchronization
import XiaolaiDictUI

/// One capture permission owner: silent status checks, at most one automatic request per process.
/// A declined lookup names System Settings rather than reopening a dialog on every hover.
struct ScreenRecordingAccess: Sendable {
    var probe: @Sendable () async -> PermissionProbe
    var request: @Sendable () -> Bool
    private let requests = ScreenRecordingRequestGate()

    init(probe: @escaping @Sendable () async -> PermissionProbe,
         request: @escaping @Sendable () -> Bool) {
        self.probe = probe
        self.request = request
    }

    static let system = ScreenRecordingAccess(
        probe: { await granted.value { await Permission.screenRecording.probe } },
        request: { Permission.screenRecording.request() })

    /// Whether HuiDict may capture, with at most one automatic request in this process.
    /// A stale signing identity can make macOS prompt despite a visible Settings grant, so the
    /// application limits requests itself and directs subsequent refused lookups to Settings.
    ///
    /// **`couldNotTell` never asks**. It used to: the probe
    /// was a Bool, so a first `SCShareableContent` call that failed in a cold process was
    /// indistinguishable from a refusal, and `ensure()` raised a system dialog on a Mac that had
    /// granted the permission three days earlier. Measured 2026-09-25 — the dialog appeared and
    /// **nothing in the system TCC database changed**, which is what a prompt that grants nothing
    /// looks like from the outside.
    ///
    /// The caller gets the third value rather than a `false`, because "we could not tell" and "you
    /// declined" send the reader to different places, and only one of them is about consent.
    func ensure() async -> PermissionProbe {
        switch await probe() {
        case .granted: return .granted
        // **A hover the reader walked away from must not raise a dialog.** `HoverReader` starts the
        // capture in a task it stops waiting for on its deadline, and giving up on the answer does
        // not stop this side: without the check, a probe that resolves `.declined` after the reader
        // has moved on still puts a system prompt on their screen, attached to nothing they asked
        // for. The probe itself is cheap and harmless to finish; only the prompt is.
        case .declined:
            guard !Task.isCancelled else { return .declined }
            return requests.once(request) ? .granted : .declined
        case .couldNotTell: return .couldNotTell
        }
    }

    private static let granted = GrantMemo()
}

/// Copies of the capture gate share this state; concurrent or repeated lookups cannot re-prompt.
private final class ScreenRecordingRequestGate: Sendable {
    private let asked = Mutex(false)

    func once(_ request: @Sendable () -> Bool) -> Bool {
        let first = asked.withLock { value in
            guard !value else { return false }
            value = true
            return true
        }
        return first && request()
    }
}

/// Remembers a grant, never a refusal.
///
/// Asking `Permission.screenRecording` costs the recogniser's own 60–85 ms, and it is a *second*
/// `SCShareableContent` fetch — it does not fill the cache the capture path reads a moment later,
/// so a per-read probe would double that step for every hover that falls back to OCR. A grant is
/// the safe thing to remember: macOS does not quietly withdraw this one mid-process, it stops the
/// process. A refusal is remembered by nothing, because the reader granting it is exactly the
/// event this has to notice.
///
/// `Mutex` rather than `NSLock` because this runs in an async context, where Swift 6 makes
/// `NSLock.lock()` unavailable outright — the compiler enforcing the rule `ShareableContentCache`
/// records in a comment. Nothing is held across the `await`: the memo is read, released, and only
/// written after the probe has answered.
private final class GrantMemo: Sendable {
    private let granted = Mutex(false)

    func value(asking probe: @Sendable () async -> PermissionProbe) async -> PermissionProbe {
        if granted.withLock({ $0 }) { return .granted }

        let answer = await probe()
        if answer == .granted { granted.withLock { $0 = true } }
        return answer
    }
}
