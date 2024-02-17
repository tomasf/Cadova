import Foundation

internal struct BasicMatrix4x4: Equatable {
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

    static func *(_ lhs: BasicMatrix4x4, _ rhs: BasicMatrix4x4) -> BasicMatrix4x4 {
        BasicMatrix4x4(rows:
            (0..<4).map { row in
                (0..<4).map { column in
                    (0..<4).map { i in
                        lhs[i, row] * rhs[column, i]
                    }.reduce(0, +)
                }
            }
        )
    }

    static func *(_ lhs: Column, _ rhs: BasicMatrix4x4) -> Row {
        (0..<4).map { column in
            (0..<4).map { row in
                rhs[column, row] * lhs[row]
            }.reduce(0, +)
        }
    }

    var inverse: BasicMatrix4x4 {
        .init(rows: invertMatrix(matrix: values))
    }
}

internal extension [Double] {
    init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
        self = [a, b, c, d]
    }
}
