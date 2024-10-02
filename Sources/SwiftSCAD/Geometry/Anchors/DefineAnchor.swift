import Foundation

internal struct DefineAnchor2D: WrappedGeometry2D {
    let body: any Geometry2D
    let anchor: Anchor
    let alignment: GeometryAlignment2D
    let transform: AffineTransform2D

    private func anchorTranslation(in environment: Environment) -> AffineTransform3D {
        let bounds = body.boundary(in: environment).boundingBox
        let alignmentTranslation = bounds?.translation(for: alignment) ?? .zero
        return AffineTransform3D.identity
            .concatenated(with: environment.transform.inverse)
            .translated(.init(alignmentTranslation))
            .concatenated(with: .init(transform.inverse))
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        var bodyElements = body.elements(in: environment)
        let bodyAnchors = bodyElements[AnchorList.self] ?? .init()
        bodyElements[AnchorList.self] = bodyAnchors.adding(anchor, at: anchorTranslation(in: environment))
        return bodyElements
    }
}

internal struct DefineAnchor3D: WrappedGeometry3D {
    let body: any Geometry3D
    let anchor: Anchor
    let alignment: GeometryAlignment3D
    let transform: AffineTransform3D

    private func anchorTranslation(in environment: Environment) -> AffineTransform3D {
        let bounds = body.boundary(in: environment).boundingBox
        let alignmentTranslation = bounds?.translation(for: alignment) ?? .zero
        return AffineTransform3D.identity
            .concatenated(with: environment.transform.inverse)
            .translated(alignmentTranslation)
            .concatenated(with: transform.inverse)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        var bodyElements = body.elements(in: environment)
        let bodyAnchors = bodyElements[AnchorList.self] ?? .init()
        bodyElements[AnchorList.self] = bodyAnchors.adding(anchor, at: anchorTranslation(in: environment))
        return bodyElements
    }
}
