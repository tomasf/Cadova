import Foundation

internal struct ApplyAnchor2D: Geometry2D {
    let body: any Geometry2D
    let anchor: Anchor

    func body(in environment: Environment) -> any Geometry2D {
        let anchors = body.elements(in: environment)[AnchorList.self]?.anchors
        guard let transform = anchors?[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        let bodyTransform = AffineTransform3D.identity
            .concatenated(with: environment.transform)
            .concatenated(with: transform)
        return body.transformed(.init(bodyTransform))
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
        let anchors = body.elements(in: environment)[AnchorList.self]?.anchors
        guard let transform = anchors?[anchor] else {
            preconditionFailure("Anchor \(anchor) not found")
        }

        let bodyTransform = AffineTransform3D.identity
            .concatenated(with: environment.transform)
            .concatenated(with: transform)
        return body.transformed(bodyTransform)
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
