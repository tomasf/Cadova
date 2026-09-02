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

        // Exactly one of this sweep's 1553 frames has no resolvable twist angle (the tangent is briefly
        // antiparallel to the `.down` target where the path runs vertically), bracketed by frames at 0°
        // and 90°. interpolateMissingAngles() used to hand it the preceding angle verbatim, leaving a
        // 0° → 0° → 90° step; it now interpolates to 45°. These figures are that corrected frame.
        #expect(m.volume ≈ 11653.029)
        #expect(m.surfaceArea ≈ 18070.705)
        #expect(m.boundingBox ≈ .init(minimum: [0, -5.60051, -3], maximum: [105.831, 100, 155.5]))
    }

    @Test func `star shape can be swept along 2D path`() async throws {
        let path = BezierPath2D {
            curve([10, 65], [50, -20], [60, 50])
        }

        let sweep = ExampleTests.Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            .swept(along: path, pointing: .negativeY, toward: .direction(.negativeZ))
        let m = try await sweep.measurements

        #expect(m.volume ≈ 13096.084)
        #expect(m.surfaceArea ≈ 9237.344)
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
        let swept = Circle(diameter: diameter).swept(along: path, pointing: .negativeY, toward: .direction(.negativeZ))
        let m = try await swept.measurements
        #expect(m.volume.equals(expectedVolume, within: expectedVolume * 0.01))
    }

    @Test func `overhangSafe shape swept along a horizontal path resolves relief using the first frame's orientation`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [100, 0, 0]])

        let plainSweep = Circle(diameter: 10)
            .swept(along: path, pointing: .down, toward: .direction(.down))
        let bridgeSweep = Circle(diameter: 10)
            .overhangSafe(.bridge)
            .swept(along: path, pointing: .down, toward: .direction(.down))

        let plainMeasurements = try await plainSweep.measurements
        let bridgeMeasurements = try await bridgeSweep.measurements

        // Before preserving the first frame's transform for the swept shape's build environment,
        // overhangSafe always saw a vertical (identity) up direction here, so it fell back to a plain
        // circle and this volume matched the unmodified sweep exactly. With the fix, the path's actual
        // starting orientation is visible, so bridge relief is added and the volume grows.
        #expect(bridgeMeasurements.volume > plainMeasurements.volume * 1.01)
    }

    @available(*, deprecated)
    @Test func `deprecated no-orientation swept(along:) produces identical geometry to explicit defaults`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [40, 0, 0], [40, 40, 0]])
        let shape = Rectangle(x: 10, y: 6).aligned(at: .center)

        let deprecatedSweep = shape.swept(along: path)
        let explicitSweep = shape.swept(along: path, pointing: .negativeY, toward: .direction(.negativeZ))

        let deprecatedMeasurements = try await deprecatedSweep.measurements
        let explicitMeasurements = try await explicitSweep.measurements

        #expect(deprecatedMeasurements.volume ≈ explicitMeasurements.volume)
        #expect(deprecatedMeasurements.surfaceArea ≈ explicitMeasurements.surfaceArea)
        #expect(deprecatedMeasurements.boundingBox == explicitMeasurements.boundingBox)
    }
}
