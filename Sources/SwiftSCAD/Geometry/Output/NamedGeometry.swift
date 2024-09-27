import Foundation

internal struct NamedGeometry: GeometryOutputElement {
    static let elementKey = GeometryOutputElementKey(rawValue: "SwiftSCAD.NamedGeometry")

    let geometry: [String: GeometryList]

    init(_ geometry: [String: GeometryList] = [:]) {
        self.geometry = geometry
    }

    static func merging(_ children: [NamedGeometry]) -> NamedGeometry {
        .init(children.map(\.geometry).reduce(into: [:]) { result, namedGeometry in
            result.merge(namedGeometry) { $0.merging(with: $1) }
        })
    }

    func adding(_ child: any Geometry2D, named name: String) -> NamedGeometry {
        .merging([self, NamedGeometry([name: .twoD([child])])])
    }

    func adding(_ child: any Geometry3D, named name: String) -> NamedGeometry {
        .merging([self, NamedGeometry([name: .threeD([child])])])
    }

    static func combine(elements: [NamedGeometry], operation: GeometryCombination) -> NamedGeometry? {
        merging(elements)
    }
}

extension NamedGeometry {
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
}

extension UniversalGeometryOutput {
    var namedGeometry: NamedGeometry? {
        elements[NamedGeometry.elementKey] as? NamedGeometry
    }
}

extension GeometryOutput {
    func naming(_ body: any Geometry2D, _ name: String) -> GeometryOutput {
        let newNamedGeometry = (namedGeometry ?? NamedGeometry()).adding(body, named: name)
        return setting(element: NamedGeometry.elementKey, to: newNamedGeometry)
    }

    func naming(_ body: any Geometry3D, _ name: String) -> GeometryOutput {
        let newNamedGeometry = (namedGeometry ?? NamedGeometry()).adding(body, named: name)
        return setting(element: NamedGeometry.elementKey, to: newNamedGeometry)
    }
}
