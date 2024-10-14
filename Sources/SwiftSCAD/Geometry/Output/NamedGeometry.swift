import Foundation

internal struct NamedGeometry: ResultElement {
    let geometry: [String: CompoundGeometry]

    init(_ geometry: [String: CompoundGeometry] = [:]) {
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

    func transformingNames(_ operation: (String) -> String) -> NamedGeometry {
        .init(Dictionary(geometry.map { (operation($0), $1) }) { $1 })
    }

    static func combine(elements: [NamedGeometry], for operation: GeometryCombination) -> NamedGeometry? {
        merging(elements)
    }
}

extension NamedGeometry {
    enum CompoundGeometry {
        case twoD ([any Geometry2D])
        case threeD ([any Geometry3D])

        func merging(with other: CompoundGeometry) -> CompoundGeometry {
            switch (self, other) {
            case (.twoD (let a), .twoD (let b)):
                return .twoD(a + b)
            case (.threeD (let a), .threeD (let b)):
                return .threeD(a + b)
            default: preconditionFailure("You can't mix 2D and 3D for the same geometry name")
            }
        }

        func codeFragment(in environment: Environment) -> CodeFragment {
            switch self {
            case .twoD (let geometry):
                geometry.usingDefaultFacets().codeFragment(in: environment)

            case .threeD (let geometry):
                geometry.usingDefaultFacets().codeFragment(in: environment)
            }
        }

        func outputFormats(in environment: Environment) -> [any OutputFormat] {
            switch self {
            case .twoD (let geometry):
                let elements = geometry.usingDefaultFacets().elements(in: environment)
                return Array(elements[OutputFormatSet2D.self]?.formats ?? [.scad])

            case .threeD (let geometry):
                let elements = geometry.usingDefaultFacets().elements(in: environment)
                return Array(elements[OutputFormatSet3D.self]?.formats ?? [.scad])
            }
        }
    }
}
