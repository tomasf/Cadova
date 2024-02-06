import Foundation

// If Accelerate is available, we use SIMD types for our matrices.
// Otherwise, we implement the basic operations we need ourselves

#if canImport(simd)

import simd
internal typealias Matrix4x4 = simd_double4x4

internal extension simd_double4x4 {
    typealias Row = SIMD4<Double>
    typealias Column = SIMD4<Double>
    static let identity = matrix_identity_double4x4
}

#else
internal typealias Matrix4x4 = BasicMatrix4x4
#endif


internal struct BasicMatrix4x4: Equatable {
    typealias Row = [Double]
    typealias Column = [Double]

    var values: [[Double]]

    init(rows: [[Double]]) {
        values = rows
    }

    subscript(_ row: Int, _ column: Int) -> Double {
        get { values[row][column] }
        set { values[row][column] = newValue }
    }

    static let identity = Self(rows: [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ])

    static func *(_ lhs: BasicMatrix4x4, _ rhs: BasicMatrix4x4) -> BasicMatrix4x4 {
        BasicMatrix4x4(rows:
            (0..<4).map { row in
                (0..<4).map { column in
                    (0..<4).map { i in
                        rhs[row, i] * lhs[i, column]
                    }.reduce(0, +)
                }
            }
        )
    }

    static func *(_ lhs: Column, _ rhs: BasicMatrix4x4) -> Row {
        (0..<4).map { index in
            rhs.values[index].enumerated().map { column, value in
                value * lhs[column]
            }.reduce(0, +)
        }
    }
}

internal extension [Double] {
    init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
        self = [a, b, c, d]
    }
}
