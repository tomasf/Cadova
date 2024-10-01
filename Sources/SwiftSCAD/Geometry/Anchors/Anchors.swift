import Foundation

public struct Anchor: Hashable {
    internal let id = UUID()
    public init() {}
}

internal struct DefineAnchor2D: WrappedGeometry2D {
    let body: any Geometry2D
    let anchor: Anchor
    let alignment: GeometryAlignment2D
    let transform: AffineTransform2D

    private func anchor(for bounds: BoundingBox2D?) -> AffineTransform3D {
        let alignmentTranslation = bounds?.translation(for: alignment)
        return AffineTransform3D.identity
            .concatenated(with: .init(transform))
            .translated(alignmentTranslation.map { -Vector3D($0) } ?? .zero)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        let anchorTransform = anchor(for: boundary(in: environment).boundingBox)
        return body.anchors(in: environment).merging([anchor: anchorTransform]) { $1 }
    }
}

internal struct DefineAnchor3D: WrappedGeometry3D {
    let body: any Geometry3D
    let anchor: Anchor
    let alignment: GeometryAlignment3D
    let transform: AffineTransform3D

    private func anchor(for bounds: BoundingBox3D?) -> AffineTransform3D {
        let alignmentTranslation = bounds?.translation(for: alignment)
        return AffineTransform3D.identity
            .concatenated(with: .init(transform))
            .translated(alignmentTranslation.map { -$0 } ?? .zero)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        let anchorTransform = anchor(for: boundary(in: environment).boundingBox)
        return body.anchors(in: environment)
            .merging([anchor: anchorTransform]) { $1 }
    }
}

internal struct ApplyAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor

    func body(in environment: Environment) -> any Geometry2D {
        let anchors = body.anchors(in: environment)
        guard let transform = anchors[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        return body.transformed(AffineTransform2D(transform.inverse))
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        body(in: environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(in: environment).boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body(in: environment).anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

internal struct ApplyAnchor3D: Geometry3D {
    let body: any Geometry3D
    let anchor: Anchor

    func body(in environment: Environment) -> any Geometry3D {
        let anchors = body.anchors(in: environment)
        guard let transform = anchors[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        return body.transformed(transform.inverse)
    }

    func codeFragment(in environment: Environment) -> CodeFragment {
        body(in: environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(in: environment).boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body(in: environment).anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

extension [[Anchor: AffineTransform3D]] {
    func combined(using transform: AffineTransform3D) -> [Anchor: AffineTransform3D] {
        reduce(into: [:]) { $0.merge($1) { a, _ in a }}
            .mapValues { $0.concatenated(with: transform) }
    }
}
