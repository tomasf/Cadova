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
    /// - Parameter profile: A 2D geometry builder describing the profile cross-section. The profile is automatically
    ///   aligned so that its bottom-right corner is at the origin.
    ///
    public init(@GeometryBuilder2D profile: @Sendable @escaping () -> any Geometry2D) {
        self.profile = Deferred(profile).aligned(at: .max)
    }

    public var negativeShape: any Geometry2D {
        readingNegativeShape { negativeShape, _ in
            negativeShape
        }
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

    func followingEdge(of shape: any Geometry2D, type: ProfilingType) -> any Geometry3D {
        readingNegativeShape { negativeShape, profileSize in
            let universeLength = 1e5
            let unitProfile = negativeShape.extruded(height: 1.0)
                .rotated(x: 90°, z: -90°)
                .translated(
                    x: 1,
                    y: type == .subtractive ? -0.01 : 0,
                    z: type == .subtractive ? 0.00002 : 0
                )

            shape.simplified().readingConcrete { crossSection in
                let polygons = crossSection.polygonList()

                @Sendable func extraLength(_ u: Vector2D, _ v: Vector2D) -> Double {
                    profileSize.x * cot(acos((u.normalized ⋅ v.normalized).clamped(to: -1.0...1.0)) / 2)
                }

                return polygons.polygons.mapUnion { polygon in
                    let vertices = Array(type == .subtractive ? polygon.vertices : polygon.vertices.reversed())
                    for index in vertices.indices {
                        let a = vertices[wrap: index - 1]
                        let b = vertices[wrap: index]
                        let c = vertices[wrap: index + 1]
                        let d = vertices[wrap: index + 2]

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
                            .translated(b, z: 0)
                            .subtracting {
                                Box(universeLength * 2)
                                    .translated(x: -1e-6)
                                    .rotated(z: Angle(bisecting: edgeAngle, a.angle(to: b)) + 90°)
                                    .translated(b, z: -universeLength)

                                Box(universeLength * 2)
                                    .translated(x: 1e-6)
                                    .rotated(z: Angle(bisecting: edgeAngle, c.angle(to: d)))
                                    .translated(c, z: -universeLength)
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
    ///   - offset: The distance to offset the profiling plane along the axis.
    ///   - type: Whether the profile should be added to or subtracted from the shape.
    /// - Returns: A new geometry with the edge profile applied on the given side.
    ///
    /// - Example:
    /// ```swift
    /// Box(10)
    ///     .applyingEdgeProfile(.fillet(radius: 3), to: .top, type: .subtractive)
    /// ```
    /// This creates a box and applies an exterior fillet to the top edges.
    ///
    func applyingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        to side: DirectionalAxis<D3>,
        offset: Double = 0,
        type: ProfilingType = .subtractive
    ) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            measuringBounds { body, bounds in
                let plane = Plane(side: side, on: bounds, offset: offset * side.axisDirection.factor)
                let shape = sliced(along: plane.offset(-profileBounds.size.y))
                applyingEdgeProfile(edgeProfile, with: shape, at: plane, type: type)
            }
        }
    }

    /// Applies an edge profile at a specified plane in 3D space.
    /// - Parameters:
    ///   - edgeProfile: The edge profile to apply.
    ///   - plane: The plane at which to apply the profile.
    ///   - type: Whether the profile should be added to or subtracted from the shape.
    /// - Returns: A new geometry with the edge profile applied at the given plane.
    ///
    func applyingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        at plane: Plane,
        type: ProfilingType = .subtractive
    ) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            let sweep = edgeProfile
                .followingEdge(of: sliced(along: plane), type: type)

            if type == .additive {
                transformed(plane.transform.inverse).adding(sweep).transformed(plane.transform)
            } else {
                transformed(plane.transform.inverse).subtracting(sweep).transformed(plane.transform)
            }
        }
    }
}

internal extension Geometry3D {
    func applyingEdgeProfile(
        _ edgeProfile: EdgeProfile,
        with shape: any Geometry2D,
        at plane: Plane,
        type: ProfilingType
    ) -> any Geometry3D {
        edgeProfile.profile.measuringBounds { _, profileBounds in
            let sweep = edgeProfile
                .followingEdge(of: shape, type: type)

            if type == .additive {
                transformed(plane.transform.inverse).adding(sweep).transformed(plane.transform)
            } else {
                transformed(plane.transform.inverse).subtracting(sweep).transformed(plane.transform)
            }
        }
    }
}

/// Describes how an ``EdgeProfile`` should be applied to a shape.
///
/// Cadova distinguishes between *subtracting* a profile (cutting material away)
/// and *adding* a profile (building material up).
///
public enum ProfilingType: Sendable, Hashable {
    /// Removes material from the host shape, carving an **exterior edge**
    /// (e.g. a chamfer or fillet on the outside of a box).
    case subtractive

    /// Adds the swept profile to the host shape, filling an **interior edge**.
    /// Useful for reinforcing or decorating inner edges with coves, beads, etc.
    case additive
}
