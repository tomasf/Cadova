import Foundation

// If Accelerate is available, we use SIMD types for our matrices.
// Otherwise, we implement the basic operations we need ourselves

#if canImport(simd)

import simd
internal typealias Matrix3x3 = simd_double3x3

internal extension simd_double3x3 {
    typealias Row = SIMD3<Double>
    typealias Column = SIMD3<Double>
    static let identity = matrix_identity_double3x3
}

internal typealias Matrix4x4 = simd_double4x4

internal extension simd_double4x4 {
    typealias Row = SIMD4<Double>
    typealias Column = SIMD4<Double>
    static let identity = matrix_identity_double4x4
}

#else
internal typealias Matrix3x3 = BasicMatrix3x3
internal typealias Matrix4x4 = BasicMatrix4x4
#endif

/// Invert a square matrix
internal func invertMatrix(matrix: [[Double]]) -> [[Double]] {
    let size = matrix.count

    var augmentedMatrix: [[Double]] = []
    for i in 0..<size {
        augmentedMatrix.append(matrix[i] + Array(repeating: 0.0, count: size))
        augmentedMatrix[i][i + size] = 1.0
    }

    for i in 0..<size {
        var maxRow = i
        for k in i + 1..<size {
            if abs(augmentedMatrix[k][i]) > abs(augmentedMatrix[maxRow][i]) {
                maxRow = k
            }
        }

        augmentedMatrix.swapAt(i, maxRow)

        let pivot = augmentedMatrix[i][i]
        guard pivot != 0 else {
            // Matrix is singular
            return matrix
        }

        for j in 0..<size * 2 {
            augmentedMatrix[i][j] /= pivot
        }

        for k in 0..<size {
            if k != i {
                let factor = augmentedMatrix[k][i]
                for j in 0..<size * 2 {
                    augmentedMatrix[k][j] -= factor * augmentedMatrix[i][j]
                }
            }
        }
    }

    return augmentedMatrix.map { Array($0[size..<size * 2]) }
}
