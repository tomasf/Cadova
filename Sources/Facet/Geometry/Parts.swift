import Foundation

struct PartAssignment: Geometry3D {
    let body: any Geometry3D
    let isSeparated: Bool
    let identifier: PartIdentifier

    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let output = body.evaluated(in: environment)
        return output.modifyingElement(PartCatalog.self) { catalog in
            (catalog ?? .init()).adding(
                part: output.modifyingManifold { $0.transform(environment.transform) },
                to: identifier
            )
        }
        .modifyingManifold { isSeparated ? .empty : $0 }
    }
}

internal struct Empty<D: Dimensionality> {
    func evaluated(in environment: EnvironmentValues) -> Output<D> { .empty }
}

extension Empty: Geometry3D where D == Dimensionality3 {}
extension Empty: Geometry2D where D == Dimensionality2 {}


public extension Geometry3D {
    func highlighted() -> any Geometry3D {
        PartAssignment(body: self.colored(.red, alpha: 0.2), isSeparated: false, identifier: .highlight)
            .colored(.transparent)
    }

    func background() -> any Geometry3D {
        PartAssignment(body: self.colored(.white, alpha: 0.3), isSeparated: true, identifier: .background)
    }

    func inPart(named name: String) -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, identifier: .named(name))
    }

    func disabled() -> any Geometry3D {
        Empty()
    }
}
