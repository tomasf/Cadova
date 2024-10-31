import Foundation

fileprivate struct _Stack<V: Vector> {
    let items: [V.Geometry]
    let axis: V.Axis
    let spacing: Double
    let alignment: GeometryAlignment<V>

    @EnvironmentValue(\.self) private var environment

    init(_ items: [V.Geometry], axis: V.Axis, alignment: GeometryAlignment<V>, spacing: Double) {
        self.items = items
        self.axis = axis
        self.alignment = alignment.defaultingToOrigin().with(axis: axis, as: .min)
        self.spacing = spacing
    }
}

extension _Stack<Vector2D>: Geometry2D, Shape2D {
    func requireBoundingBox(_ geometry: V.Geometry, in environment: Environment) -> BoundingBox<V> {
        guard let box = geometry.boundary(in: environment).boundingBox else {
            preconditionFailure("Stack item has empty bounds: \(geometry)")
        }
        return box
    }

    public var body: any Geometry2D {
        var offset = 0.0
        for geometry in items {
            let box = requireBoundingBox(geometry, in: environment)
            geometry
                .translated(box.translation(for: alignment) + .init(axis, value: offset))
            offset += box.size[axis] + spacing
        }
    }
}

extension _Stack<Vector3D>: Geometry3D, Shape3D {
    func requireBoundingBox(_ geometry: V.Geometry, in environment: Environment) -> BoundingBox<V> {
        guard let box = geometry.boundary(in: environment).boundingBox else {
            preconditionFailure("Stack item has empty bounds: \(geometry)")
        }
        return box
    }

    public var body: any Geometry3D {
        var offset = 0.0
        for geometry in items {
            let box = requireBoundingBox(geometry, in: environment)
            geometry
                .translated(box.translation(for: alignment) + .init(axis, value: offset))
            offset += box.size[axis] + spacing
        }
    }
}

/// Creates a stack of 2D geometries aligned along the specified axis with optional spacing and alignment.
///
/// - Parameters:
///   - axis: The axis along which the geometries are stacked.
///   - spacing: The spacing between stacked geometries. Default is `0`.
///   - alignment: The alignment of the stack. Can be merged from multiple alignment options.
///   - content: A closure generating geometries to stack.
/// - Returns: A stacked 2D geometry.
public func Stack(
    _ axis: Axis2D,
    spacing: Double = 0,
    alignment: GeometryAlignment2D...,
    @GeometryBuilder2D content: @escaping () -> [any Geometry2D]
) -> any Geometry2D {
    _Stack(content(), axis: axis, alignment: alignment.merged, spacing: spacing)
}

/// Creates a stack of 3D geometries aligned along the specified axis with optional spacing and alignment.
///
/// - Parameters:
///   - axis: The axis along which the geometries are stacked.
///   - spacing: The spacing between stacked geometries. Default is `0`.
///   - alignment: The alignment of the stack. Can be merged from multiple alignment options.
///   - content: A closure generating geometries to stack.
/// - Returns: A stacked 3D geometry.
public func Stack(
    _ axis: Axis3D,
    spacing: Double = 0,
    alignment: GeometryAlignment3D...,
    @GeometryBuilder3D content: @escaping () -> [any Geometry3D]
) -> any Geometry3D {
    _Stack(content(), axis: axis, alignment: alignment.merged, spacing: spacing)
}
