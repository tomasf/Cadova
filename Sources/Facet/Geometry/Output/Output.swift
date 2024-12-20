import Foundation
import Manifold

public struct Output<D: Dimensionality> {
    internal let manifold: D.Primitive
    internal let elements: ResultElementsByType

    internal init(manifold: D.Primitive, elements: ResultElementsByType) {
        self.manifold = manifold
        self.elements = elements
    }

    static var empty: Self { .init(manifold: .empty, elements: [:]) }

    /// Leaf
    init(manifold: D.Primitive) {
        self.init(manifold: manifold, elements: [:])
    }

    private func declaringColorIfNeeded(from environment: EnvironmentValues) -> Self {
        #warning("fix")
        return self
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (E?) -> E?) -> Self {
        Self(manifold: manifold, elements: elements.setting(modifier(elements[E.self])))
    }

    func withElement<E: ResultElement>(_ value: E) -> Self {
        Self(manifold: manifold, elements: elements.setting(value))
    }

    func modifyingManifold(_ modifier: (D.Primitive) -> D.Primitive) -> Self {
        Self(manifold: modifier(manifold), elements: elements)
    }

    func withManifold(_ newManifold: D.Primitive) -> Self {
        Self(manifold: newManifold, elements: elements)
    }
}

internal extension Output where D == Dimensionality2 {

    /// Combined; union, difference, intersection, minkowski
    /// Transparent for single children
    init(
        children: [Geometry2D],
        environment: EnvironmentValues,
        transformation: ([D.Primitive]) -> D.Primitive,
        combination: GeometryCombination
    ) {
        let childOutputs = children.map { $0.evaluated(in: environment) }
        if childOutputs.count == 1 {
            self = childOutputs[0]
        } else {
            self.init(
                manifold: transformation(childOutputs.map(\.manifold)),
                elements: .init(combining: childOutputs.map(\.elements), operation: combination)
            )
        }
    }

    init(
        wrapping child: Geometry2D,
        environment: EnvironmentValues,
        transformation: (D.Primitive) -> D.Primitive
    ) {
        let childOutput = child.evaluated(in: environment)
        self.init(
            manifold: transformation(childOutput.manifold),
            elements: childOutput.elements
        )
    }

    var boundingBox: BoundingBox2D {
        .init(manifold.boundingBox)
    }
}

internal extension Output where D == Dimensionality3 {
    /// Combined; union, difference, intersection, minkowski
    /// Transparent for single children
    init(
        children: [Geometry3D],
        environment: EnvironmentValues,
        transformation: ([D.Primitive]) -> D.Primitive,
        combination: GeometryCombination
    ) {
        let childOutputs = children.map { $0.evaluated(in: environment) }
        if childOutputs.count == 1 {
            self = childOutputs[0]
        } else {
            self.init(
                manifold: transformation(childOutputs.map(\.manifold)),
                elements: .init(combining: childOutputs.map(\.elements), operation: combination)
            )
        }
    }

    init(
        wrapping child: Geometry3D,
        environment: EnvironmentValues,
        transformation: (D.Primitive) -> D.Primitive
    ) {
        let childOutput = child.evaluated(in: environment)
        self.init(
            manifold: transformation(childOutput.manifold),
            elements: childOutput.elements
        )
    }

    /// Extrusion
    init(
        child: Geometry2D,
        environment: EnvironmentValues,
        transformation: (CrossSection) -> Mesh
    ) {
        let childOutput = child.evaluated(in: environment)
        self.init(
            manifold: transformation(childOutput.manifold),
            elements: childOutput.elements
        )
    }

    var boundingBox: BoundingBox3D {
        .init(manifold.boundingBox)
    }

    /*
    /// Transformed
    init(body: Geometry3D, moduleName: String, moduleParameters: CodeFragment.Parameters, transform: AffineTransform3D, environment: EnvironmentValues) {
        let environment = environment.applyingTransform(.init(transform))
        self.init(
            bodyOutput: body.evaluated(in: environment),
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            transform: transform
        )
    }
     */
}

public typealias Output2D = Output<Dimensionality2>
public typealias Output3D = Output<Dimensionality3>
