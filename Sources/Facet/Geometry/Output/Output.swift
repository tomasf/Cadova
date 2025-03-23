import Foundation
import Manifold3D

public struct Output<D: Dimensionality> {
    internal let primitive: D.Primitive
    internal let elements: ResultElementsByType

    internal init(primitive: D.Primitive, elements: ResultElementsByType) {
        if let mesh = primitive as? D3.Primitive, let error = mesh.status { //mesh.isEmpty
            preconditionFailure("Invalid mesh: \(error)")
        }
        self.primitive = primitive
        self.elements = elements
    }

    static var empty: Self { .init(primitive: .empty, elements: [:]) }

    /// Leaf
    init(primitive: D.Primitive) {
        self.init(primitive: primitive, elements: [:])
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (E?) -> E?) -> Self {
        Self(primitive: primitive, elements: elements.setting(modifier(elements[E.self])))
    }

    func withElement<E: ResultElement>(_ value: E) -> Self {
        Self(primitive: primitive, elements: elements.setting(value))
    }

    func modifyingPrimitive(_ modifier: (D.Primitive) -> D.Primitive) -> Self {
        Self(primitive: modifier(primitive), elements: elements)
    }

    func replacingPrimitive(with newPrimitive: D.Primitive) -> Self {
        Self(primitive: newPrimitive, elements: elements)
    }

    func applyingTransform(_ transform: AffineTransform3D) -> Self {
        modifyingPrimitive { $0.applyingTransform(transform) }
            .modifyingElement(PartCatalog.self) { $0?.applyingTransform(.init(transform)) }
    }

    var asGeometry: StaticGeometry<D> {
        StaticGeometry(output: self)
    }
}

internal extension Output where D == D2 {
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
                primitive: transformation(childOutputs.map(\.primitive)),
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
            primitive: transformation(childOutput.primitive),
            elements: childOutput.elements
        )
    }

    /// Projection
    init(
        child: Geometry3D,
        environment: EnvironmentValues,
        transformation: (D3.Primitive) -> CrossSection
    ) {
        let childOutput = child.evaluated(in: environment)
        self.init(
            primitive: transformation(childOutput.primitive),
            elements: childOutput.elements
        )
    }

    var boundingBox: BoundingBox2D? {
        .init(primitive.bounds)
    }
}

internal extension Output where D == D3 {
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
                primitive: transformation(childOutputs.map(\.primitive)),
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
            primitive: transformation(childOutput.primitive),
            elements: childOutput.elements
        )
    }

    /// Extrusion
    init(
        child: Geometry2D,
        environment: EnvironmentValues,
        transformation: (CrossSection) -> D3.Primitive
    ) {
        let childOutput = child.evaluated(in: environment)
        self.init(
            primitive: transformation(childOutput.primitive),
            elements: childOutput.elements
        )
    }

    var boundingBox: BoundingBox3D? {
        primitive.isEmpty ? nil : .init(primitive.bounds)
    }
}

public typealias Output2D = Output<D2>
public typealias Output3D = Output<D3>
