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

    @Test func `SVG import fills open paths by implicitly closing them`() async throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">
          <path d="M0 0 L10 0 L10 10" fill="black" />
        </svg>
        """

        let geometry = Import(svg: Data(svg.utf8), scale: .pixels)
        let measurements = try await geometry.measurements
        let bounds = try await geometry.bounds

        #expect(measurements.area.equals(50, within: 0.05))
        #expect(measurements.contourCount == 1)
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [0, 10])
        #expect(bounds!.maximum ≈ [10, 20])
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

    @Test func `SVG import resolves CSS font-family stacks`() async throws {
        // A font-family list (as commonly emitted by editors) must be parsed as a
        // fallback stack rather than treated as a single family name.
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="40" viewBox="0 0 200 40">
          <text x="0" y="30" font-size="20"
                font-family="LucidaGrande, 'Lucida Grande', sans-serif">Test</text>
        </svg>
        """
        let geometry = Import(svg: Data(svg.utf8), scale: .pixels)
        let bounds = try await geometry.bounds

        #expect(bounds != nil)
        #expect(bounds!.size.x > 0)
        #expect(bounds!.size.y > 0)
    }

    @Test func `SVG import falls back to a generic font for an unknown single family`() async throws {
        // A lone, unavailable family should still render in a fallback font
        // rather than failing the import.
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="40" viewBox="0 0 200 40">
          <text x="0" y="30" font-size="20" font-family="NoSuchFontFamily12345">Test</text>
        </svg>
        """
        let geometry = Import(svg: Data(svg.utf8), scale: .pixels)
        let bounds = try await geometry.bounds

        #expect(bounds != nil)
        #expect(bounds!.size.x > 0)
        #expect(bounds!.size.y > 0)
    }
}
