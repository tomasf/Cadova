import Foundation

internal extension Geometry3D {
    /// Cuts `edgeProfile` along `shape` at `plane`. Where the body is a plain prism of `shape`
    /// over the profile's height, the profiled part is built directly instead of cut, unless
    /// `allowsDirectConstruction` is `false` — which is how the direct construction itself asks for
    /// the cut when it can't describe a shape.
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        with shape: any Geometry2D,
        at plane: Plane,
        allowsDirectConstruction: Bool = true
    ) -> any Geometry3D {
        CuttingEdgeProfile(
            source: self,
            edgeProfile: edgeProfile,
            shape: shape,
            plane: plane,
            allowsDirectConstruction: allowsDirectConstruction
        )
    }
}

private struct CuttingEdgeProfile: Geometry3D {
    let source: any Geometry3D
    let edgeProfile: EdgeProfile
    let shape: any Geometry2D
    let plane: Plane
    let allowsDirectConstruction: Bool

    var body: any Geometry3D {
        @Environment(\.operation) var operation
        // Snapshotted into a plain `let`: `operation` is read here, but used inside the `withEnvironment`
        // closure below, which `EnvironmentModifier` stores and invokes later — potentially from deep
        // inside an already-flipped `.subtracting` branch. `@Environment`'s wrappedValue re-reads the
        // ambient environment on every access rather than snapshotting, so referencing `operation` itself
        // (instead of this pinned copy) inside that closure would silently pick up the wrong value.
        let pinnedOperation = operation

        // The traced slice describes the source body, so it must keep the source operation even though the
        // swept profile itself is evaluated in the subtraction branch.
        let sourceShape = shape.withEnvironment { $0.withOperation(pinnedOperation) }

        // Edge profiling works in plane-local coordinates, but the profiled geometry must still build in source space.
        let localSource = ApplyTransform(body: source, transform: plane.transform.inverse, transformEnvironment: false)
        let cut = localSource.subtracting(edgeProfile.followingEdge(of: sourceShape, type: .subtraction))

        ApplyTransform(
            body: allowsDirectConstruction
                ? Self.profiled(localSource, shape: sourceShape, edgeProfile: edgeProfile, cut: cut)
                : cut,
            transform: plane.transform,
            transformEnvironment: false
        )
    }

    /// The body with its edge profiled, in plane-local coordinates (the edge face at z = 0, the
    /// body below it).
    ///
    /// Cutting a profile leaves the boolean to resolve the seam where it meets the wall, which a
    /// tangent profile like a fillet makes nearly coplanar and the engine resolves into a creased
    /// line of slivers (see `ProfiledExtrusion`). Where the body is a plain prism of the profiled
    /// shape over the profile's height — which the swept cut already assumes, since it follows a
    /// single slice — that whole slab is replaced instead: the body is split below the profile and
    /// joined to a directly built profiled slab along a flat face, which booleans resolve cleanly.
    ///
    /// The prism test compares the slab's volume with the shape's area times its height, and the
    /// body's slice near the edge face with the shape itself. Anything that differs, such as a hole
    /// ending partway up, a drafted wall or a feature cut into the face, keeps the cut.
    /// The lower part of the body, trimmed where the profile starts, joined to a directly built
    /// profiled slab. The slab's rings are
    /// built on the exact points of the lower part's top face, so the two meet face to face with
    /// identical vertices and the union along that face is exact.
    private static func directlyProfiled(
        _ lower: any Geometry3D,
        shape: any Geometry2D,
        edgeProfile: EdgeProfile,
        height: Double,
        cut: any Geometry3D
    ) -> any Geometry3D {
        @Environment(\.segmentation) var segmentation

        return edgeProfile.profile.readingConcrete { profileSection -> any Geometry3D in
            lower.readingConcrete { lowerManifold, lower in
                let samples = EdgeProfile.inwardDepthSamples(of: profileSection.polygonList().polygons)
                if let levels = ProfiledExtrusion.levels(height: height, top: samples, bottom: nil),
                   let maxDepth = levels.map(\.depth).max(), maxDepth > 0,
                   let loops = ProfiledContour.boundaryLoops(ofTopFaceIn: lowerManifold.meshGL(), at: -height),
                   let contours = ProfiledContour.contours(of: loops, depth: ProfiledContour.checkDepth(for: maxDepth), segmentation: segmentation)
                {
                    shape.offset(amount: -ProfiledContour.checkDepth(for: maxDepth), style: .round).readingConcrete { erodedSection in
                        if EdgeProfile.erosionPreservesStructure(original: loops.map { SimplePolygon($0) }, deepest: erodedSection.polygonList().polygons),
                           ProfiledContour.matches(contours, erodedArea: erodedSection.area, depth: ProfiledContour.checkDepth(for: maxDepth))
                        {
                            lower.adding {
                                ProfiledExtrusion.mesh(contours: contours, levels: levels.map { (z: $0.z - height, depth: $0.depth) })
                            }
                        } else {
                            cut
                        }
                    }
                } else {
                    cut
                }
            }
        }
    }

    private static func profiled(
        _ source: any Geometry3D,
        shape: any Geometry2D,
        edgeProfile: EdgeProfile,
        cut: any Geometry3D
    ) -> any Geometry3D {
        @Environment(\.segmentation) var segmentation

        return edgeProfile.profile.readingConcrete { profileSection in
            shape.readingConcrete { section -> any Geometry3D in
                // The fold check needs nothing but the outline's own points, so it runs before the
                // trimming and measuring the prism test takes; a shape that would fold keeps the cut
                // without paying for them
                guard let samples = EdgeProfile.inwardDepthSamples(of: profileSection.polygonList().polygons),
                      let maxDepth = samples.map(\.depth).max(), maxDepth > 0,
                      ProfiledContour.contours(
                          of: section.polygonList().polygons.map { ProfiledContour.removingDuplicates($0.vertices) },
                          depth: ProfiledContour.checkDepth(for: maxDepth),
                          segmentation: segmentation
                      ) != nil
                else {
                    return cut
                }
                let area = section.area

                return edgeProfile.profile.measuringBounds { _, profileBounds in
                    let height = profileBounds.size.y
                    let lower = GeometryNodeTransformer(body: source) { .trim($0, plane: Plane.z(-height).flipped) }
                    // Measured through an intersection rather than a symmetric difference, which would
                    // evaluate the source's slice as the subtracted side of a boolean
                    let topSlice = source.sliced(atZ: -height * 1e-3)
                    let overlap = topSlice.intersecting { shape }

                    source.measuring { _, sourceMeasurements in
                        lower.measuring { _, lowerMeasurements in
                            topSlice.measuring { _, topSliceMeasurements in
                                overlap.measuring { _, overlapMeasurements in
                                    let slabVolume = await sourceMeasurements.volume - lowerMeasurements.volume
                                    let mismatchArea = await topSliceMeasurements.area + area - 2 * overlapMeasurements.area
                                    let prismVolume = area * height
                                    let isPrism = area > 0
                                        && abs(slabVolume - prismVolume) <= prismVolume * 1e-6
                                        && mismatchArea <= area * 1e-6

                                    if isPrism {
                                        directlyProfiled(lower, shape: shape, edgeProfile: edgeProfile, height: height, cut: cut)
                                    } else {
                                        cut
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

internal extension Geometry3D {
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double,
        allowsDirectConstruction: Bool
    ) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            measuringBounds { _, selfBounds in
                let plane = Plane(side: side, on: selfBounds, offset: offset * side.axisDirection.factor)
                let slicedShape = sliced(along: plane.offset(-profileBounds.size.y))
                    .ifEmpty { sliced(along: plane.offset(-1e-6)) }
                cuttingEdgeProfile(edgeProfile, with: slicedShape, at: plane, allowsDirectConstruction: allowsDirectConstruction)
            }
        }
    }
}

public extension Geometry3D {
    /// Cuts (subtracts) an edge profile along the edges where the geometry intersects a side of its bounds.
    ///
    /// The profile is swept along the slice of the shape at the given side/offset and removed
    /// from the host geometry, producing exterior features like chamfers and fillets.
    ///
    /// - Parameters:
    ///   - edgeProfile: The 2D edge profile to sweep along the edge.
    ///   - side: Which side of the geometry’s bounding box to profile (e.g. `.top`, `.right`).
    ///   - offset: Optional distance to offset the profiling plane along `side.axis`.
    ///             Positive values move toward the positive axis direction.
    /// - Returns: A new geometry with the profile cut into the selected side.
    ///
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double = 0
    ) -> any Geometry3D {
        cuttingEdgeProfile(edgeProfile, on: side, offset: offset, allowsDirectConstruction: true)
    }

    /// Cuts (subtracts) an edge profile using a custom 2D cross‑section in place of the auto‑sliced one.
    ///
    /// Use this when you want to profile along a specific cross‑section rather than the geometry’s
    /// actual slice at the profiling plane (for example, to keep a constant-width path).
    ///
    /// - Parameters:
    ///   - edgeProfile: The 2D edge profile to sweep along the edge.
    ///   - side: Which side of the geometry’s bounding box to profile.
    ///   - offset: Optional distance to offset the profiling plane along `side.axis`.
    ///   - shape: A builder that provides the cross‑section path to follow.
    /// - Returns: A new geometry with the profile cut along the provided cross‑section.
    ///
    func cuttingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        on side: DirectionalAxis<D3>,
        offset: Double = 0,
        @GeometryBuilder2D using shape: @escaping @Sendable () -> any Geometry2D
    ) -> any Geometry3D {
        measuringBounds { _, selfBounds in
            let plane = Plane(side: side, on: selfBounds, offset: offset * side.axisDirection.factor)
            cuttingEdgeProfile(edgeProfile, with: side.footprintShape(shape()), at: plane)
        }
    }
}
