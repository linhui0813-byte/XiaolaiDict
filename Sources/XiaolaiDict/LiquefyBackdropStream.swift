import AppKit
import CoreImage
import ImageIO
import XiaolaiDictUI
@preconcurrency import ScreenCaptureKit

/// The pixels behind one visible lookup. Frames stay in memory and never leave the app.
/// A stream avoids competing with the recogniser's single-shot screenshot capture.
@MainActor
final class LiquefyBackdropStream: LiquefyGlassBackdropSession {
    private let deliver: @MainActor (Data) -> Void
    private var desired: LiquefyGlassRegion?
    private var stream: SCStream?
    private var output: GlassStreamOutput?
    private var operation: Task<Void, Never>?
    private var generation = 0
    private var streamToken: UUID?
    private var retryAfter = ContinuousClock.now
    private(set) var diagnostic = "idle"

    init(deliver: @escaping @MainActor (Data) -> Void) { self.deliver = deliver }

    func update(_ region: LiquefyGlassRegion) {
        guard region.sourceRect != nil else { stop(); return }
        if desired == region {
            guard stream == nil, operation == nil, ContinuousClock.now >= retryAfter else { return }
        } else {
            if desired?.displayID != region.displayID { endStream() }
            generation += 1
            operation?.cancel(); operation = nil
            desired = region
        }
        let ticket = generation
        diagnostic = "probing"
        operation = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == ticket { self.operation = nil } }
            // Silent shared probe only. Glass never raises an automatic permission request.
            guard await ScreenRecordingAccess.system.probe() == .granted, !Task.isCancelled,
                  self.generation == ticket else {
                self.diagnostic = "preflight-unavailable"
                self.retryAfter = .now.advanced(by: .seconds(5)); return
            }
            do {
                let configuration = Self.configuration(for: region)
                if let existing = self.stream {
                    try await existing.updateConfiguration(configuration)
                    return
                }
                self.diagnostic = "finding-window"
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard !Task.isCancelled, self.generation == ticket else { return }
                guard let display = content.displays.first(where: { $0.displayID == region.displayID }) else {
                    throw StreamFailure.unavailable("display:\(region.displayID)")
                }
                guard let own = content.windows.first(where: { $0.windowID == UInt32(region.windowNumber) }) else {
                    let ownWindows = content.windows.filter {
                        $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
                    }.map(\.windowID)
                    throw StreamFailure.unavailable("window:\(region.windowNumber);own:\(ownWindows)")
                }
                let token = UUID()
                let output = GlassStreamOutput { [weak self] data in
                    Task { @MainActor [weak self] in
                        guard let self, self.desired != nil,
                              self.streamToken == token || self.generation == ticket else { return }
                        self.deliver(data)
                    }
                }
                let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: [own]),
                                      configuration: configuration, delegate: nil)
                try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
                self.diagnostic = "starting-stream"
                try await stream.startCapture()
                guard !Task.isCancelled, self.generation == ticket else {
                    try? await stream.stopCapture(); return
                }
                self.output = output; self.stream = stream; self.streamToken = token
                self.diagnostic = "streaming"
            } catch {
                guard self.generation == ticket else { return }
                self.retryAfter = .now.advanced(by: .seconds(5))
                self.endStream()
                self.diagnostic = "capture-error:\(error)"
            }
        }
    }

    func stop() {
        generation += 1
        operation?.cancel(); operation = nil
        desired = nil
        endStream()
        diagnostic = "stopped"
    }

    private func endStream() {
        let previous = stream
        stream = nil; output = nil; streamToken = nil
        if let previous { Task { try? await previous.stopCapture() } }
    }

    private static func configuration(for region: LiquefyGlassRegion) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = region.sourceRect ?? .zero
        let scale = min(region.scale, 2)
        configuration.width = max(4, Int((region.frame.width * scale).rounded()))
        configuration.height = max(4, Int((region.frame.height * scale).rounded()))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 6)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.captureResolution = .best
        return configuration
    }

    private enum StreamFailure: Error { case unavailable(String) }

    isolated deinit { stop() }
}

private final class GlassStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.linhui.huidict.glass-frames", qos: .utility)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let deliver: @Sendable (Data) -> Void

    init(deliver: @escaping @Sendable (Data) -> Void) { self.deliver = deliver }

    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sample.isValid, let buffer = sample.imageBuffer,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
                  as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue
        else { return }
        let image = CIImage(cvPixelBuffer: buffer)
        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        if let data = context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [quality: 0.9]) {
            deliver(data)
        }
    }
}
