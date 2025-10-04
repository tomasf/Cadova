import Foundation

struct NewVector<let count: Int>: Vector {
    private var values: InlineArray<count, Double>

    var x: Double { values[0] }

}

extension NewVector where count == 2 {
    var y: Double { values[0] }
}
