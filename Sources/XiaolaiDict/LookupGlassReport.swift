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
            let outcome = try await DictionaryClient().lookup("latest")
            guard case .entries = outcome else { throw Failure.dictionaryUnavailable }
            let controller = app.panelController
            let ticket = controller.newRequest()
            let presentation = LookupPresentation(
                request: ticket.number, term: "latest", lemma: Lemma(text: "late", basis: .tagger),
                source: nil, capture: .accessibility(.accessibilityTextRange, context: .complete),
                outcome: outcome)
            let frontBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
            let activeBefore = NSApp.isActive
            guard let screen = NSScreen.main,
                  controller.show(.lookup(presentation), near: UpPoint(screen.visibleFrame.origin), for: ticket)
            else { throw Failure.windowMissing("opening the lookup") }
            guard await Instrument.settle(until: .seconds(5), {
                Instrument.isOnScreen(controller.window) && controller.lastFit != nil
            }), let window = controller.window else { throw Failure.windowMissing("settling its layout") }
            try await Task.sleep(for: .milliseconds(1200))
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - window.frame.width / 2,
                                          y: screen.visibleFrame.midY - window.frame.height / 2))
            let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -40, dy: -40),
                                    styleMask: .borderless, backing: .buffered, defer: false)
            backdrop.level = .normal
            backdrop.ignoresMouseEvents = true
            backdrop.isOpaque = true
            let readingBackdrop = ReadingBackdrop()
            backdrop.contentView = readingBackdrop
            backdrop.orderFrontRegardless()
            defer { backdrop.orderOut(nil) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var captures: [String: String] = [:]
            var states: [[String: Any]] = []
            var transmission: [String: [String: Double]] = [:]
            for page in ReadingBackdrop.Page.allCases {
                readingBackdrop.page = page
                readingBackdrop.needsDisplay = true
                backdrop.display()
                try await Task.sleep(for: .milliseconds(400))
                // A reference of only our own backdrop measures actual detail transmission,
                // rather than mistaking a tint change over broad color bands for transparency.
                let referenceImage = try await capture(window: window, backdrop: backdrop, screen: screen,
                                                       includesCard: false)
                captures["\(page.rawValue)-Background"] = try save(referenceImage,
                    name: "\(page.rawValue)-Background", in: directory).path
                let reference = try interior(referenceImage, scale: screen.backingScaleFactor)
                var readings: [Int: [UInt8]] = [:]
                for value in Set([0.0, 0.25, 0.55, 0.75, original.transparency, 1.0]).sorted() {
                    // Mutate the same observable preference as the slider while this card stays open.
                    app.appearance.lookupGlass = LookupGlass(transparency: value)
                    try await Task.sleep(for: .milliseconds(400))
                    let image = try await capture(window: window, backdrop: backdrop, screen: screen)
                    let percentage = Int((value * 100).rounded())
                    let name = "\(page.rawValue)-\(percentage)"
                    captures[name] = try save(image, name: "Lookup-\(name)", in: directory).path
                    readings[percentage] = try interior(image, scale: screen.backingScaleFactor)
                    states.append(["backdrop": page.rawValue, "transparency": value,
                                   "windowNumber": window.windowNumber, "isKey": window.isKeyWindow,
                                   "appIsActive": NSApp.isActive])
                }
                guard let opaque = readings[0], let clear = readings[100] else { throw Failure.imageMissing }
                let opaqueCorrelation = try correlation(opaque, reference)
                let clearCorrelation = try correlation(clear, reference)
                transmission[page.rawValue] = ["opaqueCorrelation": opaqueCorrelation,
                                              "clearCorrelation": clearCorrelation,
                                              "gain": clearCorrelation - opaqueCorrelation]
            }
            guard let paper = transmission[ReadingBackdrop.Page.paper.rawValue] else { throw Failure.imageMissing }
            let responds = paper["clearCorrelation", default: 0] > 0.35 && paper["gain", default: 0] > 0.2
            let report: [String: Any] = [
                "bundle": Bundle.main.bundleIdentifier ?? "none", "evidence": captures,
                "states": states, "backdropTransmission": transmission,
                "cardRespondsToTransparency": responds, "term": "latest",
                "appWasActive": activeBefore, "frontmostBefore": frontBefore,
                "frontmostAfter": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none",
                "restoredTransparency": original.transparency,
            ]
            guard Instrument.write(report) else { return .failure }
            return responds ? .success : .failure
        } catch {
            _ = Instrument.write(["problem": String(describing: error)])
            return .failure
        }
    }

    private static func save(_ image: CGImage, name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("\(name).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { throw Failure.imageMissing }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.imageMissing }
        return url
    }

    private static func interior(_ image: CGImage, scale: CGFloat) throws -> [UInt8] {
        // Exclude the shadow margins, reflective edges, and rounded corners.
        let inset = 36 * scale
        guard let cropped = image.cropping(to: CGRect(x: inset, y: inset,
            width: CGFloat(image.width) - inset * 2, height: CGFloat(image.height) - inset * 2)),
              let reading = HistoryReport.Capture(image: cropped) else { throw Failure.imageMissing }
        return reading.luminance
    }

    private static func correlation(_ image: [UInt8], _ reference: [UInt8]) throws -> Double {
        guard image.count == reference.count, !image.isEmpty else { throw Failure.imageMissing }
        let count = Double(image.count)
        let imageMean = image.reduce(0.0) { $0 + Double($1) } / count
        let referenceMean = reference.reduce(0.0) { $0 + Double($1) } / count
        var covariance = 0.0, imageVariance = 0.0, referenceVariance = 0.0
        for (pixel, background) in zip(image, reference) {
            let a = Double(pixel) - imageMean, b = Double(background) - referenceMean
            covariance += a * b
            imageVariance += a * a
            referenceVariance += b * b
        }
        let denominator = (imageVariance * referenceVariance).squareRoot()
        return denominator > 0 ? covariance / denominator : 0
    }

    private static func capture(window: NSWindow, backdrop: NSWindow, screen: NSScreen,
                                includesCard: Bool = true) async throws -> CGImage {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { throw Failure.displayMissing }
        let ownWindows = includesCard ? [CGWindowID(window.windowNumber), CGWindowID(backdrop.windowNumber)]
            : [CGWindowID(backdrop.windowNumber)]
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
            guard windows.count == ownWindows.count else { throw Failure.windowMissing("capturing our own windows") }
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = source
            configuration.width = Int(source.width * scale)
            configuration.height = Int(source.height * scale)
            configuration.showsCursor = false
            return try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(display: display, including: windows), configuration: configuration)
        }
    }

    private enum Failure: Error {
        case permissionMissing, dictionaryUnavailable, windowMissing(String), displayMissing, imageMissing
    }
}

/// Native reading pages, placed behind the real floating lookup.
@MainActor
private final class ReadingBackdrop: NSView {
    enum Page: String, CaseIterable { case paper = "Paper", colored = "Colored", dark = "Dark" }
    var page = Page.paper

    override func draw(_ dirtyRect: NSRect) {
        let isDark = page == .dark
        (isDark ? NSColor(white: 0.12, alpha: 1) : .white).setFill()
        bounds.fill()
        if page == .colored {
            let colors: [NSColor] = [.systemBlue, .systemPurple, .systemTeal]
            for index in 0..<6 {
                colors[index % colors.count].withAlphaComponent(0.55).setFill()
                NSRect(x: bounds.width * CGFloat(index) / 6, y: 0,
                       width: bounds.width / 6 + 1, height: bounds.height).fill()
            }
        }
        let text = "Build my reading app. This is the latest page of the story."
        for y in stride(from: CGFloat(15), to: bounds.height, by: 28) {
            (text as NSString).draw(at: NSPoint(x: 12, y: y), withAttributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: isDark ? NSColor.white : NSColor.labelColor,
            ])
        }
    }
}
