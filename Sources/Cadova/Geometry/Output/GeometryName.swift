import Foundation

internal struct GeometryName: ResultElement {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    static func combine(elements: [GeometryName], for operation: GeometryCombination) -> GeometryName? {
        elements.first
    }
}
