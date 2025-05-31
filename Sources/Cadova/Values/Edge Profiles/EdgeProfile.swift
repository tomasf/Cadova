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
                .translated(x: 1, y: -0.01, z: 0.00002)

            shape.simplified().readingConcrete { crossSection in
                let polygons = crossSection.polygonList()

                func extraLength(_ u: Vector2D, _ v: Vector2D) -> Double {
                    profileSize.x * cot(acos((u.normalized ⋅ v.normalized).clamped(to: -1.0...1.0)) / 2)
                }

                return polygons.polygons.mapUnion { polygon in
                    for index in polygon.vertices.indices {
                        let a = polygon.vertices[wrapped: index - 1]
                        let b = polygon.vertices[wrapped: index]
                        let c = polygon.vertices[wrapped: index + 1]
                        let d = polygon.vertices[wrapped: index + 2]

                        let ba = b - a
                        let bc = b - c // vector in
                        let cb = c - b // vector out
                        let cd = c - d

                        let leadingExtension  = (ba × bc > 0) ? extraLength(ba, bc) : 0
                        let trailingExtension = (cb × cd > 0) ? extraLength(cb, cd) : 0
                        let edgeAngle = b.angle(to: c)

                        unitProfile.scaled(x: cb.magnitude + trailingExtension + leadingExtension)
                            .translated(x: -leadingExtension)
                            .rotated(z: edgeAngle)
                            .translated(Vector3D(b, z: 0))
                            .subtracting {
                                Box(universeLength * 2)
                                    .translated(x: -0.000001)
                                    .rotated(z: Angle(bisecting: edgeAngle, a.angle(to: b)) + 90°)
                                    .translated(Vector3D(b, z: -universeLength))

                                Box(universeLength * 2)
                                    .translated(x: 0.000001)
                                    .rotated(z: Angle(bisecting: edgeAngle, c.angle(to: d)))
                                    .translated(Vector3D(c, z: -universeLength))
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
