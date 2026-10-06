import AppKit
import SwiftUI
@preconcurrency import WebKit

/// A local glass region, in AppKit's bottom-left screen coordinates.
public struct LiquefyGlassRegion: Equatable, Sendable {
    public let frame: CGRect
    public let displayFrame: CGRect
    public let displayID: UInt32
    public let windowNumber: Int
    public let scale: CGFloat

    public init(frame: CGRect, displayFrame: CGRect, displayID: UInt32, windowNumber: Int, scale: CGFloat) {
        self.frame = frame; self.displayFrame = displayFrame; self.displayID = displayID
        self.windowNumber = windowNumber; self.scale = scale
    }

    /// ScreenCaptureKit uses display-local, top-left coordinates.
    public var sourceRect: CGRect? {
        guard frame.width >= Token.Glass.minimumCaptureSize, frame.height >= Token.Glass.minimumCaptureSize,
              displayFrame.contains(frame),
              [frame.minX, frame.minY, frame.width, frame.height, scale].allSatisfy(\.isFinite), scale > 0
        else { return nil }
        return CGRect(x: frame.minX - displayFrame.minX, y: displayFrame.maxY - frame.maxY,
                      width: frame.width, height: frame.height)
    }
}

@MainActor
public protocol LiquefyGlassBackdropSession: AnyObject {
    var diagnostic: String { get }
    func update(_ region: LiquefyGlassRegion)
    func stop()
}

public typealias LiquefyGlassBackdropFactory = @MainActor (
    @escaping @MainActor (Data) -> Void
) -> any LiquefyGlassBackdropSession

private struct GlassBackdropFactoryKey: EnvironmentKey {
    static let defaultValue: LiquefyGlassBackdropFactory? = nil
}

extension EnvironmentValues {
    /// Supplied by the app: the view does not request permissions or capture other apps itself.
    public var liquefyGlassBackdropFactory: LiquefyGlassBackdropFactory? {
        get { self[GlassBackdropFactoryKey.self] }
        set { self[GlassBackdropFactoryKey.self] = newValue }
    }
    /// Settings provides a rendered sample page rather than recording the desktop.
    @Entry var liquefyGlassPreviewImage: Data? = nil
}

struct LiquefyGlassSurface: NSViewRepresentable {
    @Environment(\.liquefyGlassBackdropFactory) private var factory
    @Environment(\.liquefyGlassPreviewImage) private var previewImage
    @Environment(\.lookupGlass) private var glass
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scale) private var scale
    var onReady: @MainActor (Bool) -> Void
    var onBackdropDark: @MainActor (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(factory: factory, onReady: onReady, onBackdropDark: onBackdropDark) }

    func makeNSView(context: Context) -> GlassWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = GlassWebView(frame: .zero, configuration: configuration)
        view.underPageBackgroundColor = .clear
        view.navigationDelegate = context.coordinator
        context.coordinator.view = view
        if let url = Bundle.main.url(forResource: "surface", withExtension: "html", subdirectory: "LiquefyGlass") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        context.coordinator.start()
        return view
    }

    func updateNSView(_ view: GlassWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.properties = ["transparency": glass.transparency, "radius": scale.radius.lookup,
                                  "theme": scheme == .dark ? "dark" : "light",
                                  "reduceMotion": reduceMotion, "reduceTransparency": false]
        if coordinator.previewImage != previewImage {
            coordinator.previewImage = previewImage
            if let previewImage { coordinator.send(previewImage, mime: "image/png") }
        }
        coordinator.configure()
    }

    static func dismantleNSView(_ view: GlassWebView, coordinator: Coordinator) {
        coordinator.stop()
        view.navigationDelegate = nil
        view.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var view: GlassWebView?
        var properties: [String: Any] = [:]
        var previewImage: Data?
        private let factory: LiquefyGlassBackdropFactory?
        private let onReady: @MainActor (Bool) -> Void
        private let onBackdropDark: @MainActor (Bool) -> Void
        private var lastBackdropDark: Bool?
        private var session: (any LiquefyGlassBackdropSession)?
        private var tick: Task<Void, Never>?
        private var loaded = false
        private var ready = false
        private var sending = false
        private var lastConfiguration: NSDictionary?
        private var regionDescription = "pending"

        var diagnostic: [String: Any] {
            ["loaded": loaded, "factory": factory != nil, "region": regionDescription,
             "capture": session?.diagnostic ?? "no-session"]
        }

        init(factory: LiquefyGlassBackdropFactory?, onReady: @escaping @MainActor (Bool) -> Void,
             onBackdropDark: @escaping @MainActor (Bool) -> Void) {
            self.factory = factory; self.onReady = onReady; self.onBackdropDark = onBackdropDark
        }

        func start() {
            tick = Task { [weak self] in
                while !Task.isCancelled {
                    self?.refreshRegion()
                    try? await Task.sleep(for: Token.Glass.regionRefreshInterval)
                }
            }
        }

        func stop() {
            tick?.cancel(); tick = nil
            session?.stop(); session = nil
            loaded = false
        }

        private func refreshRegion() {
            guard loaded, previewImage == nil, let view, let window = view.window, window.isVisible,
                  let screen = window.screen,
                  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
            else {
                if view?.window?.isVisible != true { session?.stop(); session = nil }
                return
            }
            if session == nil, let factory {
                session = factory { [weak self] data in self?.send(data, mime: "image/jpeg") }
            }
            let frame = window.convertToScreen(view.convert(view.bounds, to: nil))
            let region = LiquefyGlassRegion(frame: frame, displayFrame: screen.frame, displayID: displayID,
                                           windowNumber: window.windowNumber, scale: screen.backingScaleFactor)
            regionDescription = String(describing: frame)
            if region.sourceRect != nil { session?.update(region) }
            else { session?.stop(); session = nil; setReady(false) }
        }

        func configure() {
            guard loaded, let view else { return }
            let configuration = NSDictionary(dictionary: properties)
            guard configuration != lastConfiguration else { return }
            lastConfiguration = configuration
            let arguments = properties
            Task { [weak self, weak view] in
                guard let view else { return }
                do {
                    let value = try await view.callAsyncJavaScript("return await window.HuiDictGlass.configure(properties)",
                        arguments: ["properties": arguments], in: nil, contentWorld: .page)
                    if self?.loaded == true { self?.accept(value) }
                } catch { self?.setReady(false) }
            }
        }

        func send(_ data: Data, mime: String) {
            guard loaded, !sending, let view else { return }
            sending = true
            let image = "data:\(mime);base64,\(data.base64EncodedString())"
            Task { [weak self, weak view] in
                defer { self?.sending = false }
                guard let view else { return }
                do {
                    let value = try await view.callAsyncJavaScript("return await window.HuiDictGlass.frame(image)",
                        arguments: ["image": image], in: nil, contentWorld: .page)
                    if self?.loaded == true { self?.accept(value) }
                } catch { self?.setReady(false) }
            }
        }

        private func accept(_ value: Any?) {
            if let status = value as? [String: Any] {
                setReady(status["ready"] as? Bool == true)
                if let dark = status["darkBackdrop"] as? Bool, dark != lastBackdropDark {
                    lastBackdropDark = dark; onBackdropDark(dark)
                }
            } else { setReady(false) }
        }

        private func setReady(_ value: Bool) {
            guard value != ready else { return }
            ready = value; onReady(value)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true; lastConfiguration = nil; configure()
            if let previewImage { send(previewImage, mime: "image/png") }
            refreshRegion()
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            // The surface is offline. No link, remote page, or external navigation is allowed.
            let permitted = action.request.url?.isFileURL == true
                && action.request.url?.lastPathComponent == "surface.html"
            return permitted ? .allow : .cancel
        }
    }
}

/// Background-only: clicks and keyboard focus always belong to HuiDict's native controls.
final class GlassWebView: WKWebView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

public enum LiquefyGlassStatus {
    @MainActor
    public static func report(in window: NSWindow) async -> [String: Any] {
        func find(_ view: NSView) -> GlassWebView? {
            if let glass = view as? GlassWebView { return glass }
            return view.subviews.lazy.compactMap(find).first
        }
        guard let content = window.contentView, let view = find(content) else {
            return ["ready": false, "error": "surface-missing"]
        }
        do {
            var result = try await view.callAsyncJavaScript("return window.HuiDictGlass.status()",
                arguments: [:], in: nil, contentWorld: .page) as? [String: Any] ?? ["ready": false]
            result["native"] = (view.navigationDelegate as? LiquefyGlassSurface.Coordinator)?.diagnostic
            return result
        } catch { return ["ready": false, "error": String(describing: error)] }
    }
}
