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

        #expect(measurements.area ≈ 12)
        #expect(measurements.boundingBox?.center ≈ [7, 1])
        #expect(measurements.centroid ≈ Vector2D(25.0 / 3.0, 1))
    }

    @Test func `3D centroid is volume weighted`() async throws {
        let measurements = try await Box([2, 2, 2])
            .adding {
                Box([4, 2, 2])
                    .translated(x: 10)
            }
            .measurements

        #expect(measurements.volume ≈ 24)
        #expect(measurements.boundingBox?.center ≈ [7, 1, 1])
        #expect(measurements.centroid ≈ Vector3D(25.0 / 3.0, 1, 1))
    }

    @Test func `empty geometry has no centroid`() async throws {
        #expect(try await Empty<D2>().measurements.centroid == nil)
        #expect(try await Empty<D3>().measurements.centroid == nil)
    }
}
