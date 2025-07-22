import Foundation

public extension Geometry3D {
    /// Deforms 3D geometry by applying a 2D Bezier path along a given axis.
    ///
    /// This method offsets the geometry's points using a 2D path, where one axis of the path is used
    /// as the reference and the other provides the deformation offset. It is useful for applying
    /// smooth bends or distortions to 3D shapes based on a 2D curve.
    ///
    /// The `referenceAxis` is mapped to the corresponding `Axis3D` and kept unchanged, while the path controls
    /// deformation along the `targetAxis`. For example, using `.x` as the reference axis and `.z` as the target
    /// axis will offset geometry vertically using the curve defined by the path.
    ///
    /// Important: The path must be monotonic along the reference axis to ensure predictable results.
    ///
    /// - Parameters:
    ///   - targetAxis: The axis to apply deformation along (e.g. `.z`).
    ///   - referenceAxis: The axis whose value determines sampling along the path (e.g. `.x`). Must be different from `targetAxis`.
    ///                    The opposite axis of the bezier path is applied as an offset to the target axis.
    ///   - path: A 2D Bezier path used to define how points are displaced along the target axis.
    /// - Returns: A modified 3D geometry deformed according to the path.
    ///
    func deforming(_ targetAxis: Axis3D, along referenceAxis: Axis2D, using path: BezierPath2D) -> any Geometry3D {
        let referenceAxis3D = Axis3D(referenceAxis)
        precondition(referenceAxis3D != targetAxis, "Target and reference axes need to differ")

        let path3D = path.mapPoints {
            var v = Vector3D.zero
            v[referenceAxis3D] = $0[referenceAxis]
            v[targetAxis] = $0[referenceAxis.otherAxis]
            return v
        }

        return deformed(using: path3D, with: referenceAxis3D)
    }
}

public extension Geometry {
    /// Deforms geometry by offsetting its points using a Bezier path, based on a reference axis.
    ///
    /// This technique can be used for effects such as bending, tapering, or flowing geometry along a
    /// curved shape. For each point in the geometry, this method uses the value along the given reference
    /// axis to sample a position along the Bezier path. The resulting offset is applied in the other axes,
    /// while the reference axis itself remains unchanged.
    ///
    /// In 2D, this shifts the geometry in one axis based on the other (e.g., offsetting `y` based on `x`).
    /// In 3D, it offsets in two axes based on the third (e.g., offsetting `y` and `z` based on `x`).
    ///
    /// Important: The path must be monotonic along the reference axis to ensure predictable results.
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
    ///   - referenceAxis: The axis used to drive the displacement (e.g., `.x`). The geometry is offset in the other
    ///     axes.
    /// - Returns: A geometry with its shape modified according to the path.
    ///
    func deformed(using path: BezierPath<D.Vector>, with referenceAxis: D.Axis) -> D.Geometry {
        readEnvironment(\.segmentation) { segmentation in
            measuringBounds { body, bounds in
                let min = path.position(for: bounds.minimum[referenceAxis], in: referenceAxis) ?? 0
                let max = path.position(for: bounds.maximum[referenceAxis], in: referenceAxis) ?? path.fractionRange.upperBound
                let approximateLength = path[ClosedRange(min, max)].length(segmentation: .fixed(10))
                let segmentCount = segmentation.segmentCount(length: approximateLength)
                let segmentLength = bounds.size[referenceAxis] / Double(segmentCount)

                body
                    .refined(maxEdgeLength: segmentLength)
                    .warped(operationName: "deformUsingPath", cacheParameters: referenceAxis, path, segmentation) {
                        (0...segmentCount).map {
                            let value = bounds.minimum[referenceAxis] + bounds.size[referenceAxis] * Double($0) / Double(segmentCount)
                            guard let position = path.position(for: value, in: referenceAxis) else {
                                preconditionFailure("Failed to locate \(referenceAxis) = \(value) along path. Make sure the path is monotonic along the \(referenceAxis) axis and valid for all \(referenceAxis) values in the geometry.")
                            }
                            let point = path[position]
                            return (point[referenceAxis], point.with(referenceAxis, as: 0))
                        }
                    } transform: {
                        $0 + $1.binarySearchInterpolate(key: $0[referenceAxis])
                    }
                    .simplified()
            }
        }
    }
}
