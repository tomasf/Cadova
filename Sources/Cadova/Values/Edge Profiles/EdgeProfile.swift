import Foundation
import Manifold3D

/// A profile used to modify the edge of a 3D shape, such as for chamfers or fillets.
///
/// The profile is defined in 2D, where:
/// - The X axis is horizontal; negative X points inward, positive X outward from the edge
/// - The Y axis is vertical; positive Y points outward from the edge face
///
public struct EdgeProfile: Sendable {
    public let profile: any Geometry2D

    /// Creates a new edge profile.
    /// - Parameter profile: A 2D geometry builder describing the profile cross-section.
    ///   The profile is automatically aligned so that its bottom-right corner is at the origin.
    ///
    public init(@GeometryBuilder2D profile: () -> any Geometry2D) {
        self.profile = profile().aligned(at: .max)
    }
}

internal extension EdgeProfile {
    func readingNegativeShape<D: Dimensionality>(
        @GeometryBuilder<D> reader: @Sendable @escaping (_ negativeProfile: any Geometry2D, _ size: Vector2D) -> D.Geometry
    ) -> D.Geometry {
        profile.measuringBounds { shape, bounds in
            let negativeShape = Rectangle(bounds.size)
                .aligned(at: .max)
                .subtracting { shape }

            reader(negativeShape, bounds.size)
        }
    }

    func negativeMask(for shape: any Geometry2D) -> any Geometry3D {
        readingNegativeShape { negativeShape, profileSize in
            let universeLength = 1e5

            let unitProfile = negativeShape.extruded(height: 1.0)
                .rotated(x: 90°, z: -90°)
                .translated(x: 1, y: -0.000001, z: 0.00002)

            shape.readingConcrete { crossSection in
                let polygons = crossSection.polygonList()

                return polygons.polygons.mapUnion { polygon in
                    for (a, b) in polygon.vertices.wrappedPairs() {
                        unitProfile.scaled(x: (b - a).magnitude + 0.000001)
                            .rotated(z: a.angle(to: b))
                            .translated(Vector3D(a, z: 0))
                    }

                    for (a, b, c) in polygon.vertices.wrappedTriplets() {
                        let cb = c - b
                        let ab = a - b

                        // Inward corner; extended chamfers
                        if ab × cb > 0 {
                            let angle: Angle = acos(
                                ((ab ⋅ cb) / (ab.magnitude * cb.magnitude)).clamped(to: -1.0...1.0)
                            )

                            // Distance from vertex to where the innermost part of chamfers meet
                            let inset = profileSize.x * cot(angle / 2)

                            // Left side extension
                            unitProfile.scaled(x: inset + 1)
                                .translated(x: -0.001)
                                .rotated(z: a.angle(to: b))
                                .translated(Vector3D(b, z: 0))
                                .intersecting {
                                    // Mask to left of vertex
                                    Box(universeLength)
                                        .translated(y: -0.002)
                                        .rotated(z: angle / 2)
                                        .rotated(z: a.angle(to: b))
                                        .translated(Vector3D(b, z: -profileSize.y))
                                }

                            // Right side extension
                            unitProfile.scaled(x: inset + 1.001)
                                .translated(x: -inset - 1)
                                .rotated(z: b.angle(to: c))
                                .translated(Vector3D(b, z: 0))
                                .subtracting {
                                    // Mask to right of vertex
                                    Box(universeLength)
                                        .translated(y: 0.002)
                                        .rotated(z: angle / 2)
                                        .rotated(z: a.angle(to: b))
                                        .translated(Vector3D(b, z: -profileSize.y))
                                }
                        }
                    }
                }
            }
        }
    }
}

public extension Geometry3D {
    /// Applies an edge profile to a specified side of the 3D geometry.
    /// - Parameters:
    ///   - edgeProfile: The edge profile to apply.
    ///   - side: The side of the bounding box to which the profile should be applied.
    /// - Returns: A new geometry with the edge profile applied on the given side.
    ///
    func applyingEdgeProfile(_ edgeProfile: EdgeProfile, to side: DirectionalAxis<D3>) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            measuringBounds { body, bounds in
                let plane = Plane(side: side, on: bounds, offset: -profileBounds.size.y)
                applyingEdgeProfile(edgeProfile, at: plane)
            }
        }
    }

    /// Applies an edge profile at a specified plane in 3D space.
    /// - Parameters:
    ///   - edgeProfile: The edge profile to apply.
    ///   - plane: The plane at which to apply the profile.
    /// - Returns: A new geometry with the edge profile applied at the given plane.
    ///
    func applyingEdgeProfile(_ edgeProfile: EdgeProfile, at plane: Plane) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            transformed(plane.transform.inverse).subtracting {
                edgeProfile
                    .negativeMask(for: sliced(along: plane))
                    .translated(z: profileBounds.size.y)
            }
            .transformed(plane.transform)
        }
    }
}
