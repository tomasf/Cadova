import Foundation

// Container for non-Double values related to dimensions
internal struct DimensionalValues<Element: Sendable, V: Vector>: Sendable {
    typealias Axis = V.Axes.Axis

    internal enum Value {
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

    init(_ map: (Axis) -> Element) {
        self.init(Axis.allCases.map { map($0) })
    }

    init(x: Element, y: Element) where V == Vector2D {
        value = .xy(x, y)
    }

    init(x: Element, y: Element, z: Element) where V == Vector3D {
        value = .xyz(x, y, z)
    }

    func map<New>(_ operation: (_ axis: Axis, _ element: Element) -> New) -> DimensionalValues<New, V> {
        .init(Axis.allCases.map {
            operation($0, self[$0])
        })
    }

    func map<New>(_ operation: (Element) -> New) -> DimensionalValues<New, V> {
        .init(elements.map(operation))
    }

    subscript(_ index: Int) -> Element {
        elements[index]
    }

    subscript(_ axis: V.Axes.Axis) -> Element {
        elements[axis.index]
    }

    func contains(_ predicate: (Element) -> Bool) -> Bool {
        elements.contains(where: predicate)
    }
}

extension DimensionalValues where Element == Double {
    var vector: V {
        .init(elements: elements)
    }
}

extension DimensionalValues.Value: Equatable where Element: Equatable {}
extension DimensionalValues: Equatable where Element: Equatable {}
