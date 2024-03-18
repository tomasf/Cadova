import Foundation

public struct Anchor: Hashable {
    internal let id = UUID()
    public init() {}
}

internal struct DefineAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor
    let alignment: GeometryAlignment2D
    let offset: Vector2D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        let bounds = output.boundary.boundingBox
        let translation = (bounds?.translation(for: alignment) ?? .zero) + offset
        return output.definingAnchors([anchor: .translation(Vector3D(-translation))])
    }
}

internal struct DefineAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor
    let alignment: GeometryAlignment3D
    let offset: Vector3D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        let bounds = output.boundary.boundingBox
        let translation = (bounds?.translation(for: alignment) ?? .zero) + offset
        return output.definingAnchors([anchor: .translation(-translation)])
    }
}

internal struct ApplyAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor

    func output(in environment: Environment) -> Output {
        guard let transform = body.output(in: environment).anchors[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        return body
            .transformed(AffineTransform2D(transform.inverse))
            .output(in: environment)
    }
}

internal struct ApplyAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor

    func output(in environment: Environment) -> Output {
        guard let transform = body.output(in: environment).anchors[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        return body
            .transformed(transform.inverse)
            .output(in: environment)
    }
}
