import Foundation

struct PartAssignment: Geometry {
    let body: any Geometry3D
    let isSeparated: Bool
    let identifier: PartIdentifier

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D3.BuildResult {
        let output = await body.build(in: environment, context: context)
        var newOutput = output.modifyingElement(PartCatalog.self) {
            $0.add(part: output, to: identifier)
        }
        if isSeparated {
            newOutput = newOutput.replacing(expression: .empty)
        }
        return newOutput
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
