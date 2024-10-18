import Foundation

internal struct DimensionalValue<Element: Equatable & Sendable, V: Vector>: Equatable, Sendable {
    private enum Value: Equatable {
        case xy (Element, Element)
        case xyz (Element, Element, Element)
    }

    private let value: Value

    private var elements: [Element] {
        switch value {
        case let .xy(x, y): [x, y]
        case let .xyz(x, y, z): [x, y, z]
        }
    }

    init(_ elements: [Element]) {
        precondition(elements.count == V.elementCount)

        if V.self == Vector2D.self {
            value = .xy(elements[0], elements[1])
        } else if V.self == Vector3D.self {
            value = .xyz(elements[0], elements[1], elements[2])
        } else {
            preconditionFailure("Unknown vector type \(V.self)")
        }
    }

    init(_ elements: Element...) {
        self.init(elements)
    }

    init(_ map: (Int) -> Element) {
        self.init((0..<V.elementCount).map(map))
    }

    init(x: Element, y: Element) where V == Vector2D {
        value = .xy(x, y)
    }

    init(x: Element, y: Element, z: Element) where V == Vector3D {
        value = .xyz(x, y, z)
    }

    func map<New>(_ operation: (Element) -> New) -> DimensionalValue<New, V> {
        .init(elements.map(operation))
    }

    func mapVector(_ operation: (Int, Element) -> Double) -> V {
        .init(elements: elements.enumerated().map(operation))
    }

    subscript(_ index: Int) -> Element {
        elements[index]
    }

    func contains(_ predicate: (Element) -> Bool) -> Bool {
        elements.contains(where: predicate)
    }
}
