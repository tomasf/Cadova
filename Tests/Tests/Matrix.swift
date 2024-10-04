import Testing
@testable import SwiftSCAD

#if canImport(simd)
import simd

struct MatrixTests {
    @Test func equalImplementations3x3() {
        let simdMatrix1 = simd_double3x3(rows: [
            .init(45.3, 4565, -94.245),
            .init(12.4, 0, -15),
            .init(3.77, 1, 1655.33)
        ])
        let simdMatrix2 = simd_double3x3(rows: [
            .init(2, -2333.2, .pi),
            .init(100, 1, 18.1),
            .init(-1, 12, 6785.9)
        ])
        let simdVector1 = SIMD3<Double>(1255.3, -6776.2, 8)

        let basicMatrix1 = BasicMatrix3x3(rows: simdMatrix1.values)
        let basicMatrix2 = BasicMatrix3x3(rows: simdMatrix2.values)
        let basicVector1 = BasicMatrix3x3.Column(simdVector1[0], simdVector1[1], simdVector1[2])

        #expect(simdMatrix1.values ≈ basicMatrix1.values)
        #expect(simdMatrix2.values ≈ basicMatrix2.values)

        let simdMultiplied = simdMatrix1 * simdMatrix2
        let basicMultiplied = basicMatrix1 * basicMatrix2
        #expect(simdMultiplied.values ≈ basicMultiplied.values)

        let simdApplied = simdVector1 * simdMultiplied
        let basicApplied = basicVector1 * basicMultiplied
        #expect([simdApplied.x, simdApplied.y, simdApplied.z] ≈ basicApplied)

        let simdApplied2 = simdMultiplied * simdVector1
        let basicApplied2 = basicMultiplied * basicVector1
        #expect([simdApplied2.x, simdApplied2.y, simdApplied2.z] ≈ basicApplied2)

        let simdInverse = simdMatrix1.inverse
        let basicInverse = basicMatrix1.inverse
        #expect(simdInverse.values ≈ basicInverse.values)
        #expect(basicMatrix1.values ≈ basicInverse.inverse.values)
    }

    @Test func equalImplementations4x4() {
        let simdMatrix1 = simd_double4x4(rows: [
            .init(45.3, 67.2, 4565, -94.245),
            .init(12.4, 0, 45.1, -15),
            .init(1222, 3.77, 11, 566562),
            .init(55, 3.77, 1, 1655.33)
        ])
        let simdMatrix2 = simd_double4x4(rows: [
            .init(2, -2333.2, .pi, 1),
            .init(100, 1, 18.1, -1),
            .init(-1, 23, 12, 6785.9),
            .init(6776, 3424, 565, 32)
        ])
        let simdVector1 = SIMD4<Double>(1255.3, -6776.2, 8, -233.5)

        let basicMatrix1 = BasicMatrix4x4(rows: simdMatrix1.values)
        let basicMatrix2 = BasicMatrix4x4(rows: simdMatrix2.values)
        let basicVector1 = BasicMatrix4x4.Column(simdVector1[0], simdVector1[1], simdVector1[2], simdVector1[3])

        let simdMultiplied = simdMatrix1 * simdMatrix2
        let basicMultiplied = basicMatrix1 * basicMatrix2
        #expect(simdMultiplied.values ≈ basicMultiplied.values)

        let simdApplied = simdVector1 * simdMultiplied
        let basicApplied = basicVector1 * basicMultiplied
        #expect([simdApplied.x, simdApplied.y, simdApplied.z, simdApplied.w] ≈ basicApplied)

        let simdApplied2 = simdMultiplied * simdVector1
        let basicApplied2 = basicMultiplied * basicVector1
        #expect([simdApplied2.x, simdApplied2.y, simdApplied2.z, simdApplied2.w] ≈ basicApplied2)

        let simdInverse = simdMatrix1.inverse
        let basicInverse = basicMatrix1.inverse
        #expect(simdInverse.values ≈ basicInverse.values)
        #expect(basicMatrix1.values ≈ basicInverse.inverse.values)
    }
}

extension simd_double3x3 {
    var values: [[Double]] {
        (0..<3).map { [self[0][$0], self[1][$0], self[2][$0]] }
    }
}

extension simd_double4x4 {
    var values: [[Double]] {
        (0..<4).map { [self[0][$0], self[1][$0], self[2][$0], self[3][$0]] }
    }
}

#endif
