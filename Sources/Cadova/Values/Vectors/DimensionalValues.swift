import Foundation

// Container for non-Double values related to dimensions
internal struct DimensionalValues<Element: Sendable, D: Dimensionality>: Sendable {
    internal enum Value {
        case xy (Element, Element)
        case xyz (Element, Element, Element)
    }

    private let value: Value

    init(_ elements: [Element]) {
        precondition(elements.count == D.Vector.elementCount)

        if D.self == D2.self {
            value = .xy(elements[0], elements[1])
        } else if D.self == D3.self {
            value = .xyz(elements[0], elements[1], elements[2])
        } else {
            preconditionFailure("Unknown dimensionality \(D.self)")
        }
    }

    init(_ map: (D.Axis) -> Element) {
        self.init(D.Axis.allCases.map { map($0) })
    }

    subscript(_ axis: D.Axis) -> Element {
        switch value {
        case let .xy(x, y): [x, y][axis.index]
        case let .xyz(x, y, z): [x, y, z][axis.index]
        }
    }

    func map<New>(_ operation: (_ axis: D.Axis, _ element: Element) -> New) -> DimensionalValues<New, D> {
        .init(D.Axis.allCases.map {
            operation($0, self[$0])
        })
    }

    func map<New>(_ operation: (Element) -> New) -> DimensionalValues<New, D> {
        map { operation($1) }
    }

    func contains(_ predicate: (Element) -> Bool) -> Bool {
        D.Axis.allCases.contains {
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
    init(x: Element, y: Element) where D == D2 {
        value = .xy(x, y)
    }

    init(x: Element, y: Element, z: Element) where D == D3 {
        value = .xyz(x, y, z)
    }
}

extension DimensionalValues where Element == Double {
    var vector: D.Vector {
        .init { self[$0] }
    }
}

extension DimensionalValues where Element == Bool {
    var axes: D.Axes {
        Set(map { $1 ? $0 : nil }.values.compactMap(\.self))
    }
}

extension DimensionalValues.Value: Equatable where Element: Equatable {}
extension DimensionalValues: Equatable where Element: Equatable {}
extension DimensionalValues.Value: Hashable where Element: Hashable {}
extension DimensionalValues: Hashable where Element: Hashable {}
