import Testing
@testable import Cadova

struct MeasurementTests {
    @Test func `2D centroid is area weighted`() async throws {
        let measurements = try await Rectangle([2, 2])
            .adding {
                Rectangle([4, 2])
                    .translated(x: 10)
            }
            .measurements

        let area = await measurements.area
        let centroid = await measurements.centroid
        #expect(area ≈ 12)
        #expect(measurements.boundingBox?.center ≈ [7, 1])
        #expect(centroid ≈ Vector2D(25.0 / 3.0, 1))
    }

    @Test func `3D centroid is volume weighted`() async throws {
        let measurements = try await Box([2, 2, 2])
            .adding {
                Box([4, 2, 2])
                    .translated(x: 10)
            }
            .measurements

        let volume = await measurements.volume
        let centroid = await measurements.centroid
        #expect(volume ≈ 24)
        #expect(measurements.boundingBox?.center ≈ [7, 1, 1])
        #expect(centroid ≈ Vector3D(25.0 / 3.0, 1, 1))
    }

    @Test func `empty geometry has no centroid`() async throws {
        let centroid2D = await (try await Empty<D2>().measurements).centroid
        let centroid3D = await (try await Empty<D3>().measurements).centroid
        #expect(centroid2D == nil)
        #expect(centroid3D == nil)
    }
}
