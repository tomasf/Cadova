import XCTest
@testable import SwiftSCAD

#if canImport(simd)
import simd

final class MatrixTests: XCTestCase {
    func testEqualImplementations3x3() {
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

        assertEqualEnoughMatrix(simdMatrix1.values, basicMatrix1.values)
        assertEqualEnoughMatrix(simdMatrix2.values, basicMatrix2.values)

        let simdMultiplied = simdMatrix1 * simdMatrix2
        let basicMultiplied = basicMatrix1 * basicMatrix2
        assertEqualEnoughMatrix(simdMultiplied.values, basicMultiplied.values)

        let simdApplied = simdVector1 * simdMultiplied
        let basicApplied = basicVector1 * basicMultiplied
        assertEqualEnough([simdApplied.x, simdApplied.y, simdApplied.z], basicApplied)

        let simdInverse = simdMatrix1.inverse
        let basicInverse = basicMatrix1.inverse
        assertEqualEnoughMatrix(simdInverse.values, basicInverse.values)
        assertEqualEnoughMatrix(basicMatrix1.values, basicInverse.inverse.values)
    }

    func testEqualImplementations4x4() {
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
        assertEqualEnoughMatrix(simdMultiplied.values, basicMultiplied.values)

        let simdApplied = simdVector1 * simdMultiplied
        let basicApplied = basicVector1 * basicMultiplied
        assertEqualEnough([simdApplied.x, simdApplied.y, simdApplied.z, simdApplied.w], basicApplied)

        let simdInverse = simdMatrix1.inverse
        let basicInverse = basicMatrix1.inverse
        assertEqualEnoughMatrix(simdInverse.values, basicInverse.values)
        assertEqualEnoughMatrix(basicMatrix1.values, basicInverse.inverse.values)
    }

    func assertEqualEnough(_ a: [Double], _ b: [Double]) {
        XCTAssertEqual(a.count, b.count)
        for (v1, v2) in zip(a, b) {
            XCTAssertEqual(v1, v2, accuracy: 0.00001)
        }
    }

    func assertEqualEnoughMatrix(_ a: [[Double]], _ b: [[Double]]) {
        XCTAssertEqual(a.count, b.count)
        for (row1, row2) in zip(a, b) {
            assertEqualEnough(row1, row2)
        }
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
