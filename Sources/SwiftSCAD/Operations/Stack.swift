import Foundation

internal struct Stack2D: Shape2D {
    let items: [any Geometry2D]
    let axis: Axis2D
    let spacing: Double
    let alignment: GeometryAlignment2D

    public var body: any Geometry2D {
        EnvironmentReader { environment in
            var offset = 0.0
            for geometry in items {
                let output = geometry.output(in: environment)
                if let box = output.boundary.boundingBox {
                    output
                        .translated(-box.minimum)
                        .translated((box.size * -alignment.factors).with(axis, as: offset))

                    offset += box.size[axis] + spacing
                } else {
                    assertionFailure("Stack item has empty bounds: \(geometry)")
                }
            }
        }
    }
}

internal struct Stack3D: Shape3D {
    let items: [any Geometry3D]
    let axis: Axis3D
    let spacing: Double
    let alignment: GeometryAlignment3D

    public var body: any Geometry3D {
        EnvironmentReader { environment in
            var offset = 0.0
            for geometry in items {
                let output = geometry.output(in: environment)
                if let box = output.boundary.boundingBox {
                    output
                        .translated(-box.minimum)
                        .translated((box.size * -alignment.factors).with(axis, as: offset))

                    offset += box.size[axis] + spacing
                } else {
                    logger.info("Stack contains an item without a bounding box. Skipping.")
                }
            }
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
    @SequenceBuilder2D content: @escaping () -> [any Geometry2D]
) -> any Geometry2D {
    Stack2D(items: content(), axis: axis, spacing: spacing, alignment: .init(merging: alignment))
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
    @SequenceBuilder3D content: @escaping () -> [any Geometry3D]
) -> any Geometry3D {
    Stack3D(items: content(), axis: axis, spacing: spacing, alignment: .init(merging: alignment))
}
