import Foundation
import Testing
@testable import Cadova

struct TwistTests {
    /// A bar with a rectangular cross-section, so that twisting it has a visible effect.
    private func bar(height: Double) -> any Geometry3D {
        Box(x: 20, y: 4, z: height)
            .aligned(at: .centerXY)
    }

    /// The volume of the symmetric difference between two solids, relative to the volume of the first.
    ///
    /// Two twists that agree as continuous maps still meet at slightly different vertices once each has been
    /// refined and simplified on its own, so equality is judged as a fraction of the solid rather than absolutely.
    /// Anything under a thousandth is facet noise; a genuine difference in twist is orders of magnitude larger.
    private func relativeDifference(_ a: any Geometry3D, _ b: any Geometry3D) async throws -> Double {
        let difference = try await a.subtracting(b).adding(b.subtracting(a)).measurements.volume
        return try await difference / a.measurements.volume
    }

    @Test func `rate twist over the full height matches bounding box twist`() async throws {
        let bar = bar(height: 20)
        let byBounds = bar.twisted(by: 90°)
        let byRate = bar.twisted(by: 90°, per: 20)

        #expect(try await relativeDifference(byBounds, byRate) < 1e-3)
    }

    @Test func `the same twist rate can be written at any scale`() async throws {
        let bar = bar(height: 30)

        #expect(try await relativeDifference(
            bar.twisted(by: 30°, per: 10),
            bar.twisted(by: 3°, per: 1)
        ) < 1e-3)
    }

    @Test func `twist rate does not depend on the height of the geometry`() async throws {
        // The bottom 20mm of a 40mm bar must be twisted exactly like a 20mm bar at the same rate.
        let short = bar(height: 20).twisted(by: 90°, per: 20)
        let tall = bar(height: 40)
            .twisted(by: 90°, per: 20)
            .intersecting {
                Box(x: 100, y: 100, z: 20)
                    .aligned(at: .centerXY)
            }

        #expect(try await relativeDifference(short, tall) < 2e-3)

        // The same bar twisted by the bounding box instead spreads 90° over 40mm, so its bottom half is
        // visibly different. Without this, the check above could pass on a twist that ignored its arguments.
        let byBounds = bar(height: 40)
            .twisted(by: 90°)
            .intersecting {
                Box(x: 100, y: 100, z: 20)
                    .aligned(at: .centerXY)
            }
        #expect(try await relativeDifference(short, byBounds) > 0.1)
    }

    @Test func `bounding box twist ignores Z position`() async throws {
        let bar = bar(height: 20)
        let moved = bar
            .translated(z: 50)
            .twisted(by: 90°)
            .translated(z: -50)

        #expect(try await relativeDifference(bar.twisted(by: 90°), moved) < 1e-3)
    }

    @Test func `rate twist is zero at the origin plane`() async throws {
        // Twisting about z = 0 at 90° per 20mm means geometry lifted by 50mm arrives already rotated by 225°.
        // Moving it back down must leave exactly that rotation behind.
        let bar = bar(height: 20)
        let moved = bar
            .translated(z: 50)
            .twisted(by: 90°, per: 20)
            .translated(z: -50)
        let expected = bar
            .twisted(by: 90°, per: 20)
            .rotated(z: 225°)

        #expect(try await relativeDifference(expected, moved) < 1e-3)
        // ...and that this is a real rotation, not a symmetry of the bar.
        #expect(try await relativeDifference(bar.twisted(by: 90°, per: 20), moved) > 0.1)
    }

    @Test func `a twist of zero leaves the geometry untouched`() async throws {
        let bar = bar(height: 20)

        #expect(try await relativeDifference(bar, bar.twisted(by: 0°)) ≈ 0)
        #expect(try await relativeDifference(bar, bar.twisted(by: 0°, per: 10)) ≈ 0)
    }

    @Test func `a twist over zero length leaves the geometry untouched`() async throws {
        let bar = bar(height: 20)

        #expect(try await relativeDifference(bar, bar.twisted(by: 90°, per: 0)) ≈ 0)
    }

    @Test func `twisting preserves volume`() async throws {
        let bar = bar(height: 40)
        let plain = try await bar.measurements.volume
        let twisted = try await bar.twisted(by: 180°, per: 20).measurements.volume

        #expect(twisted.equals(plain, within: plain * 1e-3))
    }
}
