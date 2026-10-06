import CoreGraphics
import Testing
@testable import XiaolaiDictUI

struct LiquefyGlassRegionTests {
    @Test func mapsAnOffsetDisplayIntoTopLeftCaptureCoordinates() {
        let region = LiquefyGlassRegion(frame: CGRect(x: -1400, y: 180, width: 400, height: 300),
            displayFrame: CGRect(x: -1920, y: -200, width: 1920, height: 1080),
            displayID: 42, windowNumber: 123, scale: 2)
        #expect(region.sourceRect == CGRect(x: 520, y: 400, width: 400, height: 300))
    }

    @Test func refusesOffDisplayAndInvalidRegionsInsteadOfStretchingUnrelatedPixels() {
        let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        for frame in [CGRect(x: -10, y: 0, width: 400, height: 300),
                      CGRect(x: 100, y: 1000, width: 400, height: 300), .zero] {
            #expect(LiquefyGlassRegion(frame: frame, displayFrame: display,
                displayID: 1, windowNumber: 1, scale: 2).sourceRect == nil)
        }
        #expect(LiquefyGlassRegion(frame: CGRect(x: 10, y: 10, width: 400, height: 300),
            displayFrame: display, displayID: 1, windowNumber: 1, scale: .nan).sourceRect == nil)
    }
}
