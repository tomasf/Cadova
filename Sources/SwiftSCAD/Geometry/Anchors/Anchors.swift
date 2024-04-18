import Foundation

public struct Anchor: Hashable {
    internal let id = UUID()
    public init() {}
}

internal struct DefineAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor
    let alignment: GeometryAlignment2D
    let transform: AffineTransform2D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        let bounds = output.boundary.boundingBox
        let alignmentTranslation = bounds?.translation(for: alignment)

        let finalTransform = AffineTransform3D.identity
            .concatenated(with: .init(transform))
            .translated(alignmentTranslation.map { -Vector3D($0) } ?? .zero)

        return output.definingAnchors([anchor: finalTransform])
    }
}

internal struct DefineAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor
    let alignment: GeometryAlignment3D
    let transform: AffineTransform3D

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        let bounds = output.boundary.boundingBox
        let alignmentTranslation = bounds?.translation(for: alignment)

        let finalTransform = AffineTransform3D.identity
            .concatenated(with: transform)
            .translated(alignmentTranslation.map { -$0 } ?? .zero)

        return output.definingAnchors([anchor: finalTransform])
    }
}

internal struct ApplyAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        guard let transform = output.anchors[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        return output
            .transformed(AffineTransform2D(transform.inverse))
            .output(in: environment)
    }
}

internal struct ApplyAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor

    func output(in environment: Environment) -> Output {
        let output = body.output(in: environment)
        guard let transform = output.anchors[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        return output
            .transformed(transform.inverse)
            .output(in: environment)
    }
}
