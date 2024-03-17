import Foundation

public struct Anchor: Hashable {
    internal let id = UUID()
    public init() {}
}

public extension Anchor {
    func define() -> any Geometry2D {
        DefineAnchor2D(body: Rectangle(0), anchor: self, relativeTransform: .identity)
            .disabled()
    }

    func define() -> any Geometry3D {
        DefineAnchor3D(body: Box(0), anchor: self, relativeTransform: .identity)
            .disabled()
    }
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

internal struct DefineAlignedAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor
    let alignment: GeometryAlignment3D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)

        let bounds = output.boundary.boundingBox
        let translation = bounds?.translation(for: alignment) ?? .zero
        return output.definingAnchors([anchor: .translation(-translation)])
    }
}

internal struct DefineAlignedAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor
    let alignment: GeometryAlignment2D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)

        let bounds = output.boundary.boundingBox
        let translation = Vector3D(bounds?.translation(for: alignment) ?? .zero)
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

public extension Geometry2D {
    func definingAnchor(_ anchor: Anchor, at offset: Vector2D = .zero) -> any Geometry2D {
        DefineAnchor2D(body: self, anchor: anchor, relativeTransform: .translation(offset))
    }

    func definingAnchor(_ anchor: Anchor, at alignment: GeometryAlignment2D...) -> any Geometry2D {
        DefineAlignedAnchor2D(body: self, anchor: anchor, alignment: .init(merging: alignment))
    }

    func anchored(to anchor: Anchor) -> any Geometry2D {
        ApplyAnchor2D(body: self, anchor: anchor)
    }
}

public extension Geometry3D {
    func definingAnchor(_ anchor: Anchor, at offset: Vector3D = .zero) -> any Geometry3D {
        DefineAnchor3D(body: self, anchor: anchor, relativeTransform: .translation(offset))
    }

    func definingAnchor(_ anchor: Anchor, at alignment: GeometryAlignment3D...) -> any Geometry3D {
        DefineAlignedAnchor3D(body: self, anchor: anchor, alignment: .init(merging: alignment))
    }

    func anchored(to anchor: Anchor) -> any Geometry3D {
        ApplyAnchor3D(body: self, anchor: anchor)
    }
}
