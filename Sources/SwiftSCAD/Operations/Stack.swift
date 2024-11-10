import Foundation

public struct Stack<V: Vector> {
    private let items: [V.Geometry]
    private let axis: V.Axis
    private let spacing: Double
    private let alignment: V.Alignment

    @Environment private var environment

    fileprivate init(axis: V.Axis, spacing: Double, alignment: [V.Alignment], content: @escaping () -> [V.Geometry]
    ) {
        self.items = content()
        self.axis = axis
        self.spacing = spacing
        self.alignment = .init(merging: alignment)
            .defaultingToOrigin()
            .with(axis: axis, as: .min)
    }
}

extension Stack<Vector2D>: Geometry2D, Shape2D {
    /// Creates a stack of 2D geometries aligned along the specified axis with optional spacing and alignment.
    ///
    /// - Parameters:
    ///   - axis: The axis along which the geometries are stacked.
    ///   - spacing: The spacing between stacked geometries. Default is `0`.
    ///   - alignment: The alignment of the stack. Can be merged from multiple alignment options.
    ///   - content: A closure generating geometries to stack.
    public init(
        _ axis: Axis2D,
        spacing: Double = 0,
        alignment: GeometryAlignment2D...,
        @GeometryBuilder2D content: @escaping () -> [Geometry2D]
    ) {
        self.init(axis: axis, spacing: spacing, alignment: alignment, content: content)
    }

    public var body: any Geometry2D {
        var offset = 0.0
        for geometry in items {
            let box = requireBoundingBox(geometry)
            geometry
                .translated(box.translation(for: alignment) + .init(axis, value: offset))
            offset += box.size[axis] + spacing
        }
    }

    private func requireBoundingBox(_ geometry: V.Geometry) -> BoundingBox<V> {
        guard let box = geometry.evaluated(in: environment).boundary.boundingBox else {
            preconditionFailure("Stack item has empty bounds: \(geometry)")
        }
        return box
    }
}

extension Stack<Vector3D>: Geometry3D, Shape3D {
    /// Creates a stack of 3D geometries aligned along the specified axis with optional spacing and alignment.
    ///
    /// - Parameters:
    ///   - axis: The axis along which the geometries are stacked.
    ///   - spacing: The spacing between stacked geometries. Default is `0`.
    ///   - alignment: The alignment of the stack. Can be merged from multiple alignment options.
    ///   - content: A closure generating geometries to stack.
    public init(
        _ axis: Axis3D,
        spacing: Double = 0,
        alignment: GeometryAlignment3D...,
        @GeometryBuilder3D content: @escaping () -> [Geometry3D]
    ) {
        self.init(axis: axis, spacing: spacing, alignment: alignment, content: content)
    }

    public var body: any Geometry3D {
        var offset = 0.0
        for geometry in items {
            let box = requireBoundingBox(geometry)
            geometry
                .translated(box.translation(for: alignment) + .init(axis, value: offset))
            offset += box.size[axis] + spacing
        }
    }

    private func requireBoundingBox(_ geometry: V.Geometry) -> BoundingBox<V> {
        guard let box = geometry.evaluated(in: environment).boundary.boundingBox else {
            preconditionFailure("Stack item has empty bounds: \(geometry)")
        }
        return box
    }
}
