import Foundation

// Container for non-Double values related to dimensions
internal struct DimensionalValues<Element: Sendable, V: Vector>: Sendable {
    typealias Axis = V.Axis

    internal enum Value {
        case xy (Element, Element)
        case xyz (Element, Element, Element)
    }

    private let value: Value

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

    init(_ map: (Axis) -> Element) {
        self.init(Axis.allCases.map { map($0) })
    }

    subscript(_ axis: V.Axis) -> Element {
        switch value {
        case let .xy(x, y): [x, y][axis.index]
        case let .xyz(x, y, z): [x, y, z][axis.index]
        }
    }

    func map<New>(_ operation: (_ axis: Axis, _ element: Element) -> New) -> DimensionalValues<New, V> {
        .init(Axis.allCases.map {
            operation($0, self[$0])
        })
    }

    func map<New>(_ operation: (Element) -> New) -> DimensionalValues<New, V> {
        map { operation($1) }
    }

    func contains(_ predicate: (Element) -> Bool) -> Bool {
        Axis.allCases.contains {
            predicate(self[$0])
        }
    }

    var values: [Element] {
        switch value {
        case .xy(let x, let y): [x, y]
        case .xyz(let x, let y, let z): [x, y, z]
        }
    }
}

extension DimensionalValues {
    init(x: Element, y: Element) where V == Vector2D {
        value = .xy(x, y)
    }

    init(x: Element, y: Element, z: Element) where V == Vector3D {
        value = .xyz(x, y, z)
    }
}

extension DimensionalValues where Element == Double {
    var vector: V {
        .init { self[$0] }
    }
}

extension DimensionalValues where Element == Bool {
    var axes: V.Axes {
        Set(map { $1 ? $0 : nil }.values.compactMap(\.self))
    }
}

extension DimensionalValues.Value: Equatable where Element: Equatable {}
extension DimensionalValues: Equatable where Element: Equatable {}
extension DimensionalValues.Value: Hashable where Element: Hashable {}
extension DimensionalValues: Hashable where Element: Hashable {}
