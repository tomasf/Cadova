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
        } empty: {
            reader(Empty(), .zero)
        }
    }

    func followingEdge(of shape: any Geometry2D, type: EnvironmentValues.Operation) -> any Geometry3D {
        readingNegativeShape { negativeShape, profileSize in
            let unitProfile = negativeShape.extruded(height: 1.0)
                .rotated(x: 90°, z: -90°)
                .translated(
                    x: 1,
                    y: type == .subtraction ? -1e-2 : -1e-6,
                    z: type == .subtraction ? 1e-4 : 0
                )

            shape.simplified().readingConcrete { crossSection in
                crossSection.polygonList().polygons.mapUnion { polygon in
                    let overshoot = polygon.boundingBox.size.magnitude
                    let vertices = type == .subtraction ? polygon.vertices : Array(polygon.vertices.reversed())
                    for index in vertices.indices {
                        let a = vertices[wrap: index - 1]
                        let b = vertices[wrap: index]
                        let c = vertices[wrap: index + 1]
                        let d = vertices[wrap: index + 2]

                        let ba = b - a
                        let cb = c - b
                        let dc = d - c

                        let startLine = Line(point: b, direction: .init(bisecting: ba, cb).counterclockwiseNormal)
                        let endLine = Line(point: c, direction: .init(bisecting: cb, dc).counterclockwiseNormal)

                        unitProfile.scaled(x: cb.magnitude + 2 * overshoot)
                            .translated(x: -overshoot)
                            .rotated(z: b.angle(to: c))
                            .translated(b, z: 0)
                            .trimmed(along: Plane(line: startLine).offset(-1e-6))
                            .trimmed(along: Plane(line: endLine).flipped.offset(-1e-6))
                    }
                }
            }
        }
    }
}
