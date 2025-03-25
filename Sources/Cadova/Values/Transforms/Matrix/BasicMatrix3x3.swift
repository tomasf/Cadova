import Foundation

internal struct BasicMatrix3x3: Equatable, Sendable {
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
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1]
    ])

    static func *(_ lhs: BasicMatrix3x3, _ rhs: BasicMatrix3x3) -> BasicMatrix3x3 {
        BasicMatrix3x3(rows:
            (0..<3).map { row in
                (0..<3).map { column in
                    (0..<3).map { i in
                        lhs[i, row] * rhs[column, i]
                    }.reduce(0, +)
                }
            }
        )
    }

    static func *(_ lhs: Column, _ rhs: BasicMatrix3x3) -> Row {
        (0..<3).map { column in
            (0..<3).map { row in
                rhs[column, row] * lhs[row]
            }.reduce(0, +)
        }
    }

    static func *(_ lhs: BasicMatrix3x3, _ rhs: Column) -> Row {
        (0..<3).map { index in
            lhs.values[index].enumerated().map { column, value in
                value * rhs[column]
            }.reduce(0, +)
        }
    }

    var inverse: BasicMatrix3x3 {
        .init(rows: invertMatrix(matrix: values))
    }
}

internal extension [Double] {
    init(_ a: Double, _ b: Double, _ c: Double) {
        self = [a, b, c]
    }
}
