import Foundation

public struct Anchor: Hashable {
    internal let id = UUID()
    public init() {}
}

internal struct DefineAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor
    let relativeTransform: AffineTransform2D

    func output(in environment: Environment) -> Output {
        body.output(in: environment)
            .definingAnchors([anchor: AffineTransform3D(relativeTransform)])
    }
}

internal struct DefineAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor
    let relativeTransform: AffineTransform3D

    func output(in environment: Environment) -> Output {
        body.output(in: environment)
            .definingAnchors([anchor: relativeTransform])
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

public extension Geometry2D {
    func definingAnchor(_ anchor: Anchor, at offset: Vector2D = .zero) -> any Geometry2D {
        DefineAnchor2D(body: self, anchor: anchor, relativeTransform: .translation(offset))
    }

    func anchored(to anchor: Anchor) -> any Geometry2D {
        ApplyAnchor2D(body: self, anchor: anchor)
    }
}

public extension Geometry3D {
    func definingAnchor(_ anchor: Anchor, at offset: Vector3D = .zero) -> any Geometry3D {
        DefineAnchor3D(body: self, anchor: anchor, relativeTransform: .translation(offset))
    }

    func anchored(to anchor: Anchor) -> any Geometry3D {
        ApplyAnchor3D(body: self, anchor: anchor)
    }
}
