import Foundation

public extension Geometry3D {
    private func resized(_ alignment: GeometryAlignment3D, _ calculator: @escaping (Vector3D) -> Vector3D) -> any Geometry3D {
        return measuringBounds { geometry, box in
            geometry
                .translated(-box.minimum - alignment.factors * box.size)
                .scaled(calculator(box.size) / box.size)
                .translated(box.minimum + alignment.factors * box.size)
        }
    }

    /// Resizes the geometry to specific dimensions in 3D space.
    /// - Parameters:
    ///   - x: The target size in the X direction.
    ///   - y: The target size in the Y direction.
    ///   - z: The target size in the Z direction.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, aligning to `.center` maintains the geometry's center, while `.top` aligns with the top edge of its original position. By default, a geometry is resized relative to its origin.
    /// - Returns: A new geometry resized and repositioned according to the specified dimensions and alignment.

    func resized(x: Double, y: Double, z: Double, alignment: GeometryAlignment3D...) -> any Geometry3D {
        resized(alignment.merged) { _ in Vector3D(x, y, z) }
    }

    /// Resizes the geometry in the X direction with optional behaviors in the other directions.
    /// - Parameters:
    ///   - x: The target size in the X direction.
    ///   - y: The resize behavior for the Y direction.
    ///   - z: The resize behavior for the Z direction.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, aligning to `.center` maintains the geometry's center, while `.top` aligns with the top edge of its original position. By default, a geometry is resized relative to its origin.
    /// - Returns: A new geometry resized and aligned according to the specified behaviors and alignment.

    func resized(x: Double, y: ResizeBehavior = .fixed, z: ResizeBehavior = .fixed, alignment: GeometryAlignment3D...) -> any Geometry3D {
        resized(alignment.merged) { current in
            Vector3D(
                x,
                y.value(current: current.y, from: current.x, to: x),
                z.value(current: current.z, from: current.x, to: x)
            )
        }
    }

    /// Resizes the geometry in the Y direction with optional behaviors in the other directions.
    /// - Parameters:
    ///   - x: The resize behavior for the X direction.
    ///   - y: The target size in the Y direction.
    ///   - z: The resize behavior for the Z direction.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, aligning to `.center` maintains the geometry's center, while `.top` aligns with the top edge of its original position. By default, a geometry is resized relative to its origin.
    /// - Returns: A new geometry resized and aligned according to the specified behaviors and alignment.

    func resized(x: ResizeBehavior = .fixed, y: Double, z: ResizeBehavior = .fixed, alignment: GeometryAlignment3D...) -> any Geometry3D {
        resized(alignment.merged) { current in
            Vector3D(
                x.value(current: current.x, from: current.y, to: y),
                y,
                z.value(current: current.z, from: current.y, to: y)
            )
        }
    }

    /// Resizes the geometry in the Z direction with optional behaviors in the other directions.
    /// - Parameters:
    ///   - x: The resize behavior for the X direction.
    ///   - y: The resize behavior for the Y direction.
    ///   - z: The target size in the Z direction.
    ///   - alignment: Determines the reference point for the geometry's position during resizing. Aligning affects how the geometry is repositioned to maintain its alignment relative to its bounding box after resizing. For example, aligning to `.center` maintains the geometry's center, while `.top` aligns with the top edge of its original position. By default, a geometry is resized relative to its origin.
    /// - Returns: A new geometry resized and aligned according to the specified behaviors and alignment.

    func resized(x: ResizeBehavior = .fixed, y: ResizeBehavior = .fixed, z: Double, alignment: GeometryAlignment3D...) -> any Geometry3D {
        resized(alignment.merged) { current in
            Vector3D(
                x.value(current: current.x, from: current.z, to: z),
                y.value(current: current.y, from: current.z, to: z),
                z
            )
        }
    }
}
