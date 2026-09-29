import Foundation

/// A smooth curved surface defined by a two-dimensional grid of Bézier curves.
///
/// `BezierPatch` represents a bicubic Bézier surface, a common construct in computer graphics
/// and 3D modeling used to describe smooth, continuous surfaces such as car bodies, furniture, and other organic forms.
///
/// A Bézier patch is built from a rectangular grid of control points. Each row and column of control points
/// defines a Bézier curve, and the surface itself is constructed by interpolating first across one axis
/// (typically `v`) and then across the other (`u`). The patch provides a smooth surface bounded by the convex hull of
/// its control points.
///
/// ### Usage
///
/// To create a Bézier patch, provide a 2D array of control points:
///
/// ```swift
/// BezierPatch(controlPoints: [
///     [ [0, 3, 0],   [1, 3, 0.4], [2, 3, 0.1],  [3.5, 3, 1.2] ],
///     [ [0, 2, 0.4], [1, 2, 1.2], [2, 2, 1],    [3, 2, 0.2]   ],
///     [ [0, 1, 0.5], [1, 1, 1.5], [2, 1, 0.3],  [3, 1, -0.4]  ],
///     [ [0, 0, 0],   [1, 0, 0.8], [2, 0, -0.2], [3, 0, 0]     ],
/// ])
/// .enclosed(against: Plane.z(-0.5))
/// .aligned(at: .bottom)
/// ```
///
/// ### Applications
///
/// Bézier patches are ideal for:
/// - Sculpted surfaces and smooth organic shapes
/// - Parametric modeling
/// - Surface lofting and extrusion
/// - Transitioning between arbitrary curves
///
/// - SeeAlso: `BezierPatch.extruded(to:)`
///
public struct BezierPatch: ParametricSurface {
    let controlPoints: [[Vector3D]] // rows × columns

    public init(controlPoints: [[Vector3D]]) {
        precondition(!controlPoints.isEmpty)
        let columnCount = controlPoints[0].count
        precondition(columnCount >= 2, "Each row must have at least two control points")
        precondition(controlPoints.allSatisfy { $0.count == columnCount }, "All rows must have the same number of control points")
        self.controlPoints = controlPoints
    }

    /// Returns the point on the patch at the given parameters.
    ///
    /// `u` runs across the rows of control points and `v` along each row.
    ///
    /// - Parameter uv: The surface parameters, with both `u` (`x`) and `v` (`y`) in `0...1`.
    /// - Returns: The point on the patch.
    public func point(at uv: Vector2D) -> Vector3D {
        // V direction (columns)
        let intermediatePoints: [Vector3D] = controlPoints.map { row in
            BezierCurve(controlPoints: row).point(at: uv.y)
        }

        // U direction (rows)
        return BezierCurve(controlPoints: intermediatePoints).point(at: uv.x)
    }

}

extension BezierPatch: Transformable {
    /// Transform all control points using an affine transform
    public func transformed(_ transform: Transform3D) -> Self {
        Self(controlPoints: controlPoints.map { row in
            row.map { transform.apply(to: $0) }
        })
    }
}

extension BezierPatch: CustomDebugStringConvertible {
    public var debugDescription: String {
        controlPoints
            .map { row in row.map { $0.debugDescription }.joined(separator: ", ") }
            .joined(separator: "\n")
    }
}
