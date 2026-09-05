import Foundation

public extension Geometry {
    /// Attracts each point of the geometry toward the given point.
    ///
    /// The amount each point is moved depends on the distance to the target,
    /// the provided falloff function, the specified influence radius, and the maximum movement.
    ///
    /// - Parameters:
    ///   - target: The point to attract toward.
    ///   - influenceRadius: The distance within which points are affected. Points beyond this radius are unaffected.
    ///   - maxMovement: The maximum distance any point may be moved, even if the falloff would suggest more.
    ///   - falloff: A shaping function defining the strength of the attraction. It is evaluated on
    ///     proximity to the target: 1 at the target itself and 0 at the influence radius. Defaults to
    ///     `.smoothstep`, which pulls hardest close to the target and fades smoothly to nothing at the
    ///     edge of the influence. If `nil`, full strength is used everywhere within the influence
    ///     radius, which leaves a step at its boundary.
    /// - Returns: A new geometry attracted toward the target.
    ///
    func attracted(
        toward target: D.Vector,
        influenceRadius: Double,
        maxMovement: Double,
        falloff: ShapingFunction? = .smoothstep
    ) -> D.Geometry {
        attracted(
            towardTarget: target as! any AttractionTarget<D>,
            influenceRadius: influenceRadius,
            maxMovement: maxMovement,
            falloff: falloff
        )
    }

    /// Attracts each point of the geometry toward the closest point on the given line.
    ///
    /// The amount each point is moved depends on the distance to the line,
    /// the provided falloff function, the specified influence radius, and the maximum movement.
    ///
    /// - Parameters:
    ///   - line: The line to attract toward.
    ///   - influenceRadius: The distance within which points are affected. Points beyond this radius are unaffected.
    ///   - maxMovement: The maximum distance any point may be moved, even if the falloff would suggest more.
    ///   - falloff: A shaping function defining the strength of the attraction. It is evaluated on
    ///     proximity to the target: 1 at the target itself and 0 at the influence radius. Defaults to
    ///     `.smoothstep`, which pulls hardest close to the target and fades smoothly to nothing at the
    ///     edge of the influence. If `nil`, full strength is used everywhere within the influence
    ///     radius, which leaves a step at its boundary.
    /// - Returns: A new geometry attracted toward the line.
    ///
    func attracted(
        toward line: D.Line,
        influenceRadius: Double,
        maxMovement: Double,
        falloff: ShapingFunction? = .smoothstep
    ) -> D.Geometry {
        attracted(towardTarget: line, influenceRadius: influenceRadius, maxMovement: maxMovement, falloff: falloff)
    }
}

public extension Geometry3D {
    /// Attracts each point of the geometry toward the closest point on the given plane.
    ///
    /// The amount each point is moved depends on the distance to the plane,
    /// the provided falloff function, the specified influence radius, and the maximum movement.
    ///
    /// - Parameters:
    ///   - plane: The plane to attract toward.
    ///   - influenceRadius: The distance within which points are affected. Points beyond this radius are unaffected.
    ///   - maxMovement: The maximum distance any point may be moved, even if the falloff would suggest more.
    ///   - falloff: A shaping function defining the strength of the attraction. It is evaluated on
    ///     proximity to the target: 1 at the target itself and 0 at the influence radius. Defaults to
    ///     `.smoothstep`, which pulls hardest close to the target and fades smoothly to nothing at the
    ///     edge of the influence. If `nil`, full strength is used everywhere within the influence
    ///     radius, which leaves a step at its boundary.
    /// - Returns: A new geometry attracted toward the plane.
    ///
    func attracted(
        toward plane: Plane,
        influenceRadius: Double,
        maxMovement: Double,
        falloff: ShapingFunction? = .smoothstep
    ) -> D.Geometry {
        attracted(towardTarget: plane, influenceRadius: influenceRadius, maxMovement: maxMovement, falloff: falloff)
    }
}

// MARK: - Internal

internal extension Geometry {
    func attracted(
        towardTarget target: any AttractionTarget<D>,
        influenceRadius: Double,
        maxMovement: Double,
        falloff: ShapingFunction?
    ) -> D.Geometry {
        let function = falloff?.function

        return measuringBounds { geometry, bounds in
            @Environment(\.scaledSegmentation) var segmentation

            // A warp only relocates the vertices a mesh already has, so the surface has to be dense
            // enough to follow the attraction before it happens. The deformation varies over the
            // influence radius, but never over more than the geometry itself; refining finer than
            // the smaller of the two only adds triangles that carry no extra shape.
            let deformationScale = min(influenceRadius, bounds.size.max() ?? 0)

            geometry
                .refinedForDeformation(scale: deformationScale, segmentation: segmentation)
                .warped(
                    operationName: "Cadova.AttractTowardTarget",
                    cacheParameters: target, influenceRadius, maxMovement, falloff
                ) { point in
                    let to = target.pullTarget(for: point)
                    let offset = to - point
                    let length = offset.magnitude
                    guard length > 1e-6 else { return point }
                    guard length <= influenceRadius else { return point }

                    // The falloff is evaluated on proximity, not distance: 1 at the target and 0 at
                    // the influence radius. That way a rising function such as `.smoothstep` pulls
                    // hardest close to the target and fades to nothing exactly where the influence
                    // ends, leaving the deformation continuous across that boundary.
                    let proximity = 1 - length / influenceRadius
                    let amount = min(length, maxMovement)
                    return point + offset.normalized * (function?(proximity) ?? 1.0) * amount
                }
                .simplified()
        }
    }
}

private extension Geometry {
    /// Subdivides the geometry finely enough to follow a deformation that varies over `scale`.
    ///
    /// Geometry with no measurable extent has no edges worth subdividing, and asking `refined` for a
    /// non-positive maximum edge length is a programming error, so it is left alone.
    ///
    /// The kernel's `refine` is global, so this cost scales with the whole body while the benefit is
    /// local to the influence radius. Attracting on a 10mm box takes 0.31s, on a 50mm box 5.7s and
    /// on a 100mm box 21.8s, at a 1mm influence radius in every case; the influence radius itself
    /// barely moves the figure. All three simplify back to 12 triangles, so the cost is wall clock
    /// rather than output size. Refining only the region that can move would need a kernel operation
    /// that does not exist yet.
    @GeometryBuilder<D>
    func refinedForDeformation(scale: Double, segmentation: Segmentation) -> D.Geometry {
        if scale > .ulpOfOne {
            refined(maxEdgeLength: scale / Double(segmentation.segmentCount(length: scale)))
        } else {
            self
        }
    }
}
