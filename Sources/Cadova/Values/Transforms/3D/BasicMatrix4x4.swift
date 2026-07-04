import Foundation

// Fallback for platforms without simd. On Apple platforms, this type is only
// used by tests that validate it against simd; the availability annotation
// satisfies InlineArray's OS requirement there and is ignored elsewhere.
@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
internal struct BasicMatrix4x4: Equatable, Sendable {
    typealias Row = InlineArray<4, Double>
    typealias Column = InlineArray<4, Double>

    var values: InlineArray<4, Row>

    init(rows: [Row]) {
        precondition(rows.count == 4, "BasicMatrix4x4 requires exactly 4 rows")
        values = .init { rows[$0] }
    }

    init(rows: [[Double]]) {
        self.init(rows: rows.map(Row.init))
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

    static func == (lhs: Self, rhs: Self) -> Bool {
        for row in 0..<4 {
            for column in 0..<4 where lhs[column, row] != rhs[column, row] {
                return false
            }
        }
        return true
    }

    static func *(_ lhs: Self, _ rhs: Self) -> Self {
        var result = identity
        for row in 0..<4 {
            for column in 0..<4 {
                var sum = 0.0
                for i in 0..<4 {
                    sum += lhs[i, row] * rhs[column, i]
                }
                result[column, row] = sum
            }
        }
        return result
    }

    static func *(_ lhs: Column, _ rhs: Self) -> Row {
        Row { column in
            var sum = 0.0
            for row in 0..<4 {
                sum += rhs[column, row] * lhs[row]
            }
            return sum
        }
    }

    static func *(_ lhs: Self, _ rhs: Column) -> Row {
        Row { row in
            var sum = 0.0
            for column in 0..<4 {
                sum += lhs[column, row] * rhs[column]
            }
            return sum
        }
    }

    var rowArrays: [[Double]] {
        (0..<4).map { row in
            (0..<4).map { column in values[row][column] }
        }
    }

    var inverse: Self {
        Self(rows: invertMatrix(matrix: rowArrays))
    }
}
