import Foundation

struct PartAssignment: Geometry3D {
    let body: any Geometry3D
    let isSeparated: Bool
    let identifier: PartIdentifier

    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let output = body.evaluated(in: environment)
        return output.modifyingElement(PartCatalog.self) { catalog in
            (catalog ?? .init()).adding(part: output, to: identifier)
        }
        .modifyingPrimitive { isSeparated ? .empty : $0 }
    }
}

public extension Geometry3D {
    func highlighted() -> any Geometry3D {
        PartAssignment(body: self, isSeparated: false, identifier: .highlight)
            .colored(.transparent)
    }

    func background() -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, identifier: .background)
    }

    func inPart(named name: String, type: PartType = .solid) -> any Geometry3D {
        PartAssignment(body: self, isSeparated: true, identifier: .named(name, type: type))
    }

    func hidden() -> any Geometry3D {
        Empty()
    }
}
