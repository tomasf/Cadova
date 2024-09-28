import Foundation

public typealias GeometryOutput2D = GeometryOutput<Vector2D>
public typealias GeometryOutput3D = GeometryOutput<Vector3D>

public struct GeometryOutput<V: Vector> {
    internal let scadCode: String
    internal let boundary: Boundary<V>
    internal let anchors: [Anchor: AffineTransform3D]
    internal let elements: GeometryOutputElements

    internal init(
        scadCode: String,
        boundary: Boundary<V>,
        anchors: [Anchor: AffineTransform3D],
        elements: GeometryOutputElements
    ) {
        self.scadCode = scadCode
        self.boundary = boundary
        self.anchors = anchors
        self.elements = elements
    }
}

extension GeometryOutput {
    func modifyingCode(_ function: (_ code: String) -> String) -> GeometryOutput {
        .init(scadCode: function(scadCode), boundary: boundary, anchors: anchors, elements: elements)
    }

    func definingAnchors(_ anchors: [Anchor: AffineTransform3D]) -> GeometryOutput {
        .init(scadCode: scadCode, boundary: boundary, anchors: self.anchors.merging(anchors) { $1 }, elements: elements)
    }

    func modifyingBoundary(_ function: (Boundary<V>) -> Boundary<V>) -> GeometryOutput {
        .init(scadCode: scadCode, boundary: function(boundary), anchors: anchors, elements: elements)
    }

    func settingElements(_ newElements: GeometryOutputElements) -> GeometryOutput {
        .init(scadCode: scadCode, boundary: boundary, anchors: anchors, elements: newElements)
    }

    func setting<E: GeometryOutputElement>(element: E?) -> GeometryOutput {
        var newElements = elements
        newElements[E.self] = element
        return settingElements(newElements)
    }
}

extension GeometryOutput {
    // Without children
    init(invocation: Invocation, boundary: Boundary<V>) {
        scadCode = invocation.scadCode()
        self.boundary = boundary
        anchors = [:]
        elements = [:]
    }

    // 2D parent with 2D children
    init(
        invocation: Invocation,
        body: [any Geometry2D],
        bodyTransform: AffineTransform3D = .identity,
        environment: Environment,
        boundaryMergeStrategy: Boundary2D.MergeStrategy = .union,
        combination: GeometryCombination
    ) where V == Vector2D {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutputs = body.map { $0.output(in: newEnvironment) }

        let localBounds = bodyOutputs.map {
            $0.boundary.transformed(AffineTransform2D(bodyTransform))
        }

        scadCode = invocation.scadCode(body: bodyOutputs.map(\.scadCode))
        boundary = boundaryMergeStrategy.apply(localBounds)
        anchors = bodyOutputs.map(\.anchors)
            .reduce(into: [:]) { $0.merge($1) { a, _ in a }}
            .mapValues { $0.concatenated(with: bodyTransform) }
        elements = GeometryOutputElements.combine(bodyOutputs.map(\.elements), operation: combination)
    }

    // 2D parent with 2D child
    init(
        invocation: Invocation,
        body: any Geometry2D,
        bodyTransform: AffineTransform3D = .identity,
        environment: Environment
    ) where V == Vector2D {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutput = body.output(in: newEnvironment)

        scadCode = invocation.scadCode(body: [bodyOutput.scadCode])
        boundary = bodyOutput.boundary.transformed(AffineTransform2D(bodyTransform))
        anchors = bodyOutput.anchors.mapValues { $0.concatenated(with: bodyTransform) }
        elements = bodyOutput.elements
    }

    // 2D parent with 3D child
    init(
        invocation: Invocation,
        body: any Geometry3D,
        bodyTransform: AffineTransform3D = .identity,
        environment: Environment,
        boundaryMapping: ((Boundary3D) -> Boundary2D)
    ) where V == Vector2D {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutput = body.output(in: newEnvironment)

        scadCode = invocation.scadCode(body: [bodyOutput.scadCode])
        boundary = boundaryMapping(bodyOutput.boundary.transformed(bodyTransform))
        anchors = bodyOutput.anchors
            .mapValues { $0.concatenated(with: bodyTransform) }
        elements = bodyOutput.elements
    }

    // 3D parent with 3D children
    init(
        invocation: Invocation,
        body: [any Geometry3D],
        bodyTransform: AffineTransform3D = .identity,
        environment: Environment,
        boundaryMergeStrategy: Boundary3D.MergeStrategy = .union,
        combination: GeometryCombination
    ) where V == Vector3D {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutputs = body.map { $0.output(in: newEnvironment) }

        let localBounds = bodyOutputs.map {
            $0.boundary.transformed(bodyTransform)
        }

        scadCode = invocation.scadCode(body: bodyOutputs.map(\.scadCode))
        boundary = boundaryMergeStrategy.apply(localBounds)
        anchors = bodyOutputs.map(\.anchors)
            .reduce(into: [:]) { $0.merge($1) { a, _ in a }}
            .mapValues { $0.concatenated(with: bodyTransform) }
        elements = GeometryOutputElements.combine(bodyOutputs.map(\.elements), operation: combination)
    }

    // 3D parent with 3D child
    init(
        invocation: Invocation,
        body: any Geometry3D,
        bodyTransform: AffineTransform3D = .identity,
        environment: Environment
    ) where V == Vector3D {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutput = body.output(in: newEnvironment)

        scadCode = invocation.scadCode(body: [bodyOutput.scadCode])
        boundary = bodyOutput.boundary.transformed(bodyTransform)
        anchors = bodyOutput.anchors.mapValues { $0.concatenated(with: bodyTransform) }
        elements = bodyOutput.elements
    }

    // 3D parent with 2D child
    init(
        invocation: Invocation,
        body: any Geometry2D,
        bodyTransform: AffineTransform3D = .identity,
        environment: Environment,
        boundaryMapping: ((Boundary2D) -> Boundary3D)
    ) where V == Vector3D {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutput = body.output(in: newEnvironment)

        scadCode = invocation.scadCode(body: [bodyOutput.scadCode])
        boundary = boundaryMapping(bodyOutput.boundary).transformed(bodyTransform)
        anchors = bodyOutput.anchors
            .mapValues { $0.concatenated(with: bodyTransform) }
        elements = bodyOutput.elements
    }
}

extension GeometryOutput {
    static var emptyLeaf: Self { .init(scadCode: ";", boundary: .empty, anchors: [:], elements: [:]) }
}

protocol UniversalGeometryOutput {
    var scadCode: String { get }
    var elements: GeometryOutputElements { get }
}

extension GeometryOutput: UniversalGeometryOutput {}
