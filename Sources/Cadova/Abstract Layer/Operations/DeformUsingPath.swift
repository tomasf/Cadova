import Foundation

public extension Geometry3D {
    /// Deforms geometry by offsetting its points using a Bezier path, based on a reference axis.
    ///
    /// This is a convenience overload for 3D geometry using a 2D path.
    /// See `deformed(using:with:)` for full details.
    ///
    /// This method can be used for various effects such as bending geometry along a curve.
    ///
    func deformed(using path: BezierPath2D, with referenceAxis: Axis2D) -> any Geometry3D {
        deformed(using: path.path3D, with: Axis3D(referenceAxis))
    }
}

public extension Geometry {
    /// Deforms geometry by offsetting its points using a Bezier path, based on a reference axis.
    ///
    /// For each point in the geometry, this method uses the value along the given reference axis
    /// to sample a position along the Bezier path. The resulting offset is applied in the other axes,
    /// while the reference axis itself remains unchanged.
    ///
    /// In 2D, this shifts the geometry in one axis based on the other (e.g., offsetting `y` based on `x`).
    /// In 3D, it offsets in two axes based on the third (e.g., offsetting `y` and `z` based on `x`).
    ///
    /// This technique can be used for effects such as bending, tapering, or flowing geometry along a curved shape.
    ///
    /// The path must be monotonic along the reference axis to ensure predictable results.
    ///
    /// Example:
    /// ```swift
    /// Box(x: 100, y: 3, z: 20)
    ///     .deformed(using: BezierPath2D {
    ///         curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
    ///     }, with: .x)
    /// ```
    ///
    /// - Parameters:
    ///   - path: The Bezier path that defines the displacement, interpreted as a function of the reference axis.
    ///   - referenceAxis: The axis used to drive the displacement (e.g., `.x`). The geometry is offset in the other axes.
    /// - Returns: A geometry with its shape modified according to the path.
    ///
    func deformed(using path: BezierPath<D.Vector>, with referenceAxis: D.Axis) -> D.Geometry {
        readEnvironment(\.segmentation) { segmentation in
            measuringBounds { body, bounds in
                let min = path.position(for: bounds.minimum[referenceAxis], in: referenceAxis) ?? 0
                let max = path.position(for: bounds.maximum[referenceAxis], in: referenceAxis) ?? path.positionRange.upperBound
                let approximateLength = path.length(segmentation: .fixed(10), in: ClosedRange(min, max))
                let segmentCount = segmentation.segmentCount(length: approximateLength)

                let lookupTable = (0...segmentCount).map {
                    let value = bounds.minimum[referenceAxis] + bounds.size[referenceAxis] * Double($0) / Double(segmentCount)
                    let position = path.position(for: value, in: referenceAxis) ?? 0
                    let point = path[position]
                    return (point[referenceAxis], point.with(referenceAxis, as: 0))
                }

                let segmentLength = bounds.size[referenceAxis] / Double(segmentCount)
                body
                    .refined(maxEdgeLength: segmentLength)
                    .warped(operationName: "deformUsingPath", cacheParameters: referenceAxis, path, segmentation) {
                        $0 + lookupTable.binarySearchInterpolate(key: $0[referenceAxis])
                    }
                    .simplified()
            }
        }
    }
}
