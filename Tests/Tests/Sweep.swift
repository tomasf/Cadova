import Foundation
import Testing
@testable import Cadova

struct SweepTests {
    @Test func `shape can be swept along 3D bezier path`() async throws {
        let shape = Rectangle(x: 10, y: 6)
            .aligned(at: .center)
            .adding {
                Circle(diameter: 5)
                    .translated(x: 2, y: 3)
            }
            .subtracting {
                Rectangle(x: 8, y: 4)
                    .aligned(at: .center)
            }

        let path = BezierPath3D {
            line(x: 50)
            curve(controlX: 100, controlY: 0, controlZ: 0, endX: 100, endY: 0, endZ: 50)
            curve(controlX: 100, controlY: 0, controlZ: 150, endX: 100, endY: 50, endZ: 150)
            line(y: 100)
        }

        let sweep = shape
            .swept(along: path, pointing: .down, toward: .direction(.down))
            .withSegmentation(minAngle: 4°, minSize: 0.3)

        let m = try await sweep.measurements

        #expect(m.volume ≈ 11652.720)
        #expect(m.surfaceArea ≈ 18070.740)
        #expect(m.boundingBox ≈ .init(minimum: [0, -5.595, -3], maximum: [105.831, 100, 155.5]))
    }

    @Test func `star shape can be swept along 2D path`() async throws {
        let path = BezierPath2D {
            curve([10, 65], [50, -20], [60, 50])
        }

        let sweep = ExampleTests.Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            .swept(along: path)
        let m = try await sweep.measurements

        #expect(m.volume ≈ 13096.100)
        #expect(m.surfaceArea ≈ 9237.346)
        #expect(m.boundingBox ≈ .init(minimum: [-10.8721, -1.38221, -10.5105], maximum: [68.9987, 51.5556, 10.5105]))
    }

    @Test func `sharp corner is mitered instead of squished`() async throws {
        // Same volume-preservation invariant as Loft's equivalent test: sweeping a constant circular
        // cross-section along two straight segments meeting at a sharp corner should preserve
        // crossSectionArea * (L1 + L2), since a correct miter joint neither adds nor removes material.
        let diameter = 16.0
        let area = Double.pi * (diameter / 2) * (diameter / 2)
        let start = Vector3D(0, 0, 0), corner = Vector3D(0, 0, 40), end = Vector3D(40, 0, 40)
        let expectedVolume = area * ((corner - start).magnitude + (end - corner).magnitude)

        let path = BezierPath3D(linesBetween: [start, corner, end])
        let swept = Circle(diameter: diameter).swept(along: path)
        let m = try await swept.measurements
        #expect(m.volume.equals(expectedVolume, within: expectedVolume * 0.01))
    }
}
