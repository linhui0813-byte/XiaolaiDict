import AppKit
import DictionaryModel
import ImageIO
import ScreenCaptureKit
import XiaolaiDictBase
import XiaolaiDictCore
import XiaolaiDictUI

/// Opt-in validation of the actual unfocused lookup window, not the in-window Settings preview.
/// Captures only the app's own card and test backdrop. No events or history writes.
@MainActor
enum LookupGlassReport {
    static func run(in app: XiaolaiDictApp, directory: URL) async -> CommandStatus {
        let original = app.appearance.lookupGlass
        defer {
            app.appearance.lookupGlass = original
            app.panelController.close()
        }
        do {
            guard await Permission.screenRecording.probe == .granted else { throw Failure.permissionMissing }
            let outcome = try await DictionaryClient().lookup("refused")
            guard case .entries = outcome else { throw Failure.dictionaryUnavailable }
            let controller = app.panelController
            let ticket = controller.newRequest()
            let presentation = LookupPresentation(
                request: ticket.number, term: "refused", lemma: Lemma(text: "refuse", basis: .tagger),
                source: nil, capture: .accessibility(.accessibilityTextRange, context: .complete),
                outcome: outcome)
            let frontBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
            let activeBefore = NSApp.isActive
            guard let screen = NSScreen.main,
                  controller.show(.lookup(presentation), near: UpPoint(screen.visibleFrame.origin), for: ticket)
            else { throw Failure.windowMissing }
            guard await Instrument.settle(until: .seconds(5), {
                Instrument.isOnScreen(controller.window) && controller.lastFit != nil
            }), let window = controller.window else { throw Failure.windowMissing }
            try await Task.sleep(for: .milliseconds(600))
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - window.frame.width / 2,
                                          y: screen.visibleFrame.midY - window.frame.height / 2))
            let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -40, dy: -40),
                                    styleMask: .borderless, backing: .buffered, defer: false)
            backdrop.level = .normal
            backdrop.ignoresMouseEvents = true
            backdrop.isOpaque = true
            backdrop.contentView = ReadingBackdrop()
            backdrop.orderFrontRegardless()
            defer { backdrop.orderOut(nil) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var captures: [String: String] = [:]
            var readings: [Int: [UInt8]] = [:]
            var states: [[String: Any]] = []
            for value in Set([0.0, 0.55, original.transparency, 1.0]).sorted() {
                // Mutate the same observable preference as the slider while this card stays open.
                app.appearance.lookupGlass = LookupGlass(transparency: value)
                try await Task.sleep(for: .milliseconds(500))
                let image = try await capture(window: window, backdrop: backdrop, screen: screen)
                let percentage = Int((value * 100).rounded())
                let url = directory.appendingPathComponent("Lookup-\(percentage).png")
                guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
                else { throw Failure.imageMissing }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.imageMissing }
                captures[String(percentage)] = url.path
                // Exclude the transparent shadow margin and rounded corners from the measurement.
                let inset = 36 * screen.backingScaleFactor
                guard let interior = image.cropping(to: CGRect(x: inset, y: inset,
                    width: CGFloat(image.width) - inset * 2, height: CGFloat(image.height) - inset * 2)),
                      let reading = HistoryReport.Capture(image: interior) else { throw Failure.imageMissing }
                readings[percentage] = reading.luminance
                states.append(["transparency": value, "windowNumber": window.windowNumber,
                               "isKey": window.isKeyWindow, "appIsActive": NSApp.isActive])
            }
            if let readingBackdrop = backdrop.contentView as? ReadingBackdrop {
                readingBackdrop.isDark = true
                readingBackdrop.needsDisplay = true
                backdrop.display()
                try await Task.sleep(for: .milliseconds(500))
                let image = try await capture(window: window, backdrop: backdrop, screen: screen)
                let url = directory.appendingPathComponent("Lookup-Dark-100.png")
                guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
                else { throw Failure.imageMissing }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.imageMissing }
                captures["Dark-100"] = url.path
            }
            guard let opaque = readings[0], let clear = readings[100], opaque.count == clear.count,
                  !opaque.isEmpty else { throw Failure.imageMissing }
            let fraction = Double(zip(opaque, clear).filter { abs(Int($0) - Int($1)) > 24 }.count)
                / Double(opaque.count)
            let report: [String: Any] = [
                "bundle": Bundle.main.bundleIdentifier ?? "none", "evidence": captures,
                "states": states, "sliderChangedCardFraction": fraction,
                "cardRespondsToTransparency": fraction > 0.25,
                "appWasActive": activeBefore, "frontmostBefore": frontBefore,
                "frontmostAfter": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none",
                "restoredTransparency": original.transparency,
            ]
            guard Instrument.write(report) else { return .failure }
            return fraction > 0.25 ? .success : .failure
        } catch {
            _ = Instrument.write(["problem": String(describing: error)])
            return .failure
        }
    }

    private static func capture(window: NSWindow, backdrop: NSWindow, screen: NSScreen) async throws -> CGImage {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { throw Failure.displayMissing }
        let ownWindows = [CGWindowID(window.windowNumber), CGWindowID(backdrop.windowNumber)]
        let frame = window.frame
        let source = CGRect(x: frame.minX - screen.frame.minX, y: screen.frame.maxY - frame.maxY,
                            width: frame.width, height: frame.height)
        let scale = screen.backingScaleFactor
        return try await withDeadline(.seconds(15)) {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw Failure.displayMissing
            }
            let windows = content.windows.filter { ownWindows.contains($0.windowID) }
            guard windows.count == 2 else { throw Failure.windowMissing }
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = source
            configuration.width = Int(source.width * scale)
            configuration.height = Int(source.height * scale)
            configuration.showsCursor = false
            return try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(display: display, including: windows), configuration: configuration)
        }
    }

    private enum Failure: Error { case permissionMissing, dictionaryUnavailable, windowMissing, displayMissing, imageMissing }
}

/// Native test window with colored reading content, placed behind the real floating lookup.
@MainActor
private final class ReadingBackdrop: NSView {
    var isDark = false

    override func draw(_ dirtyRect: NSRect) {
        (isDark ? NSColor(white: 0.12, alpha: 1) : .white).setFill()
        bounds.fill()
        let colors: [NSColor] = [.systemBlue, .systemPurple, .systemTeal]
        for index in 0..<6 {
            colors[index % colors.count].withAlphaComponent(isDark ? 0.15 : 0.55).setFill()
            NSRect(x: bounds.width * CGFloat(index) / 6, y: 0,
                   width: bounds.width / 6 + 1, height: bounds.height).fill()
        }
        let text = "The proposal was refused. We kept reading to understand the story."
        for y in stride(from: CGFloat(15), to: bounds.height, by: 28) {
            (text as NSString).draw(at: NSPoint(x: 12, y: y), withAttributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: isDark ? NSColor.white : NSColor.labelColor,
            ])
        }
    }
}
