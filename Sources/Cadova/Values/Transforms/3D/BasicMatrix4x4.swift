import Foundation

internal struct BasicMatrix4x4: Equatable, Sendable {
    typealias Row = [Double]
    typealias Column = [Double]

    var values: [[Double]]

    init(rows: [[Double]]) {
        values = rows
    }

    subscript(_ column: Int, _ row: Int) -> Double {
        get { values[row][column] }
        set { values[row][column] = newValue }
    }

    static let identity = Self(rows: [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ])

    static func *(_ lhs: Self, _ rhs: Self) -> Self {
        Self(rows:
            (0..<4).map { row in
                (0..<4).map { column in
                    (0..<4).map { i in
                        lhs[i, row] * rhs[column, i]
                    }.reduce(0, +)
                }
            }
        )
    }

    static func *(_ lhs: Column, _ rhs: Self) -> Row {
        (0..<4).map { column in
            (0..<4).map { row in
                rhs[column, row] * lhs[row]
            }.reduce(0, +)
        }
    }

    static func *(_ lhs: Self, _ rhs: Column) -> Row {
        (0..<4).map { row in
            (0..<4).map { column in
                lhs[column, row] * rhs[column]
            }.reduce(0, +)
        }
    }

    var inverse: Self {
        .init(rows: invertMatrix(matrix: values))
    }
}

internal extension [Double] {
    init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
        self = [a, b, c, d]
    }
}
