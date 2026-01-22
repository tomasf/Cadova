import Foundation
import Testing
@testable import Cadova

struct SVGImportTests {
    @Test func `SVG import converts filled shapes`() async throws {
        let url = Bundle.module.url(forResource: "svg_rect_circle", withExtension: "svg", subdirectory: "resources")!
        let geometry = Import(svg: url, scale: .pixels)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area.equals(100 + 25 * Double.pi, within: 0.05))
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [0, 10])
        #expect(bounds!.maximum ≈ [20, 20])
    }

    @Test func `SVG import converts stroked paths`() async throws {
        let url = Bundle.module.url(forResource: "svg_stroke_path", withExtension: "svg", subdirectory: "resources")!
        let geometry = Import(svg: url, scale: .pixels)
        let bounds = try await geometry.bounds

        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [-1, 9])
        #expect(bounds!.maximum ≈ [11, 21])
    }

    @Test func `SVG import converts text`() async throws {
        let url = Bundle.module.url(forResource: "svg_text", withExtension: "svg", subdirectory: "resources")!
        let geometry = Import(svg: url, scale: .pixels)
        let bounds = try await geometry.bounds

        #expect(bounds != nil)
        // Text should have some bounds - exact values depend on font metrics
        #expect(bounds!.size.x > 0)
        #expect(bounds!.size.y > 0)
    }
}
