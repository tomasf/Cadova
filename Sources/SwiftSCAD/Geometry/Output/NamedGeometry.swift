import Foundation

enum GeometryList {
    case twoD ([any Geometry2D])
    case threeD ([any Geometry3D])

    func merging(with other: GeometryList) -> GeometryList {
        switch (self, other) {
        case (.twoD (let a), .twoD (let b)): return .twoD(a + b)
        case (.threeD (let a), .threeD (let b)): return .threeD(a + b)
        default: preconditionFailure("You can't mix 2D and 3D for the same geometry name")
        }
    }

    func output(in environment: Environment) -> any UniversalGeometryOutput {
        switch self {
        case .twoD (let geometry):
            Union2D(children: geometry).output(in: environment)

        case .threeD (let geometry):
            Union3D(children: geometry).output(in: environment)
        }
    }
}

internal typealias NamedGeometry = [String: GeometryList]

internal extension NamedGeometry {
    static func merging(_ children: [NamedGeometry]) -> NamedGeometry {
        children.reduce(into: [:]) { result, namedGeometry in
            result.merge(namedGeometry) { $0.merging(with: $1) }
        }
    }

    func adding(_ child: any Geometry2D, named name: String) -> NamedGeometry {
        .merging([self, [name: .twoD([child])]])
    }

    func adding(_ child: any Geometry3D, named name: String) -> NamedGeometry {
        .merging([self, [name: .threeD([child])]])
    }
}
