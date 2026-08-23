import Foundation
import Testing
@testable import Cadova

struct ExtrudeAlongTransformsTests {
    @Test func `overhangSafe shape extruded along transforms resolves relief using the first transform's orientation`() async throws {
        // Rotating x:90° tips the circle's disk into the XZ plane (normal along Y), so translating
        // along Y extrudes it along its own normal instead of sliding it around within its own plane.
        let path: [Transform3D] = [
            .rotation(x: 90°),
            .rotation(x: 90°).translated(Vector3D(0, 30, 0))
        ]

        let plainExtrusion = Circle(diameter: 10)
            .extruded(along: path)
        let bridgeExtrusion = Circle(diameter: 10)
            .overhangSafe(.bridge)
            .extruded(along: path)

        let plainMeasurements = try await plainExtrusion.measurements
        let bridgeMeasurements = try await bridgeExtrusion.measurements

        // Before building the cross-section under the environment of path[0], overhangSafe always saw
        // a vertical (identity) up direction here, so it fell back to a plain circle and this volume
        // matched the unmodified extrusion exactly. With the fix, the first transform's actual
        // orientation is visible, so bridge relief is added and the volume's magnitude grows.
        #expect(abs(bridgeMeasurements.volume) > abs(plainMeasurements.volume) * 1.01)
    }
}
