import Foundation
import Manifold3D

/// A profile used to modify the edge of a 3D shape, such as for chamfers or fillets.
///
/// The profile is defined in 2D, where:
/// - The X axis is horizontal; negative X points inward, positive X outward from the edge
/// - The Y axis is vertical; positive Y points outward from the edge face
///
/// Edge profiles are angle-relative: they're designed for a reference angle (default 90°)
/// and automatically adapt when applied to edges with different angles. This means a "centered chamfer"
/// always bisects the corner regardless of the edge angle.
///
public struct EdgeProfile: Sendable {
    public let profile: any Geometry2D

    /// The edge angle this profile is designed for.
    ///
    /// When applied to edges with different angles, the profile is automatically adapted
    /// to maintain consistent visual appearance.
    public let referenceAngle: Angle

    /// Optional generator that creates the profile for a specific edge angle.
    ///
    /// When present, this is used instead of the default transformation-based adaptation,
    /// allowing profiles like fillets to generate proper arcs for different angles.
    internal let profileGenerator: (@Sendable (Angle) -> any Geometry2D)?

    /// Creates a new edge profile.
    /// - Parameters:
    ///   - referenceAngle: The edge angle this profile is designed for. Defaults to 90°.
    ///   - profile: A 2D geometry builder describing the profile cross-section. The profile is automatically
    ///     aligned so that its bottom-right corner is at the origin.
    ///
    public init(
        referenceAngle: Angle = 90°,
        @GeometryBuilder2D profile: @Sendable @escaping () -> any Geometry2D
    ) {
        self.referenceAngle = referenceAngle
        self.profile = profile().aligned(at: .max)
        self.profileGenerator = nil
    }

    /// Creates an angle-adaptive edge profile.
    ///
    /// This initializer allows creating profiles that regenerate themselves for different
    /// edge angles, rather than using geometric transformation. This is ideal for arc-based
    /// profiles like fillets, where the arc should span the actual edge angle.
    ///
    /// - Parameters:
    ///   - referenceAngle: The edge angle this profile is designed for. Defaults to 90°.
    ///   - generator: A closure that generates the profile for a given edge angle.
    ///
    internal init(
        referenceAngle: Angle = 90°,
        generator: @Sendable @escaping (Angle) -> any Geometry2D
    ) {
        self.referenceAngle = referenceAngle
        self.profile = generator(referenceAngle).aligned(at: .max)
        self.profileGenerator = { angle in generator(angle).aligned(at: .max) }
    }

    /// The negative shape for a 90° edge (rectangle minus profile).
    public var negativeShape: any Geometry2D {
        negativeShape(for: 90°)
    }

    /// Creates the negative shape for a specific edge angle.
    ///
    /// The negative shape is a wedge of the specified angle minus the profile.
    /// For 90°, this is a rectangle minus the profile. For other angles,
    /// it's the corresponding wedge shape.
    ///
    /// - Parameter edgeAngle: The angle of the edge to generate the negative shape for.
    /// - Returns: The negative shape geometry.
    ///
    public func negativeShape(for edgeAngle: Angle) -> any Geometry2D {
        readingNegativeShape(for: edgeAngle) { negativeShape, _ in
            negativeShape
        }
    }
}

internal extension EdgeProfile {
    /// Creates a wedge shape for the given angle and size.
    ///
    /// The wedge has its corner at the origin, with one edge along positive X
    /// and the other edge at the specified angle from X.
    ///
    static func wedge(angle: Angle, size: Double) -> any Geometry2D {
        // For 90°, this is a rectangle (actually a right triangle extended)
        // For other angles, it's a triangular wedge
        let farPoint = size * 2 // Extend well beyond the profile
        let endDirection = Vector2D(x: cos(angle), y: sin(angle))

        return Polygon([
            .zero,
            Vector2D(x: -farPoint, y: 0),
            Vector2D(x: -farPoint, y: -farPoint), // Corner for 90° case
            -endDirection * farPoint
        ])
    }

    func readingNegativeShape<D: Dimensionality>(
        for edgeAngle: Angle = 90°,
        @GeometryBuilder<D> reader: @Sendable @escaping (_ negativeProfile: any Geometry2D, _ size: Vector2D) -> D.Geometry
    ) -> D.Geometry {
        profile.measuringBounds { shape, bounds in
            // Use the profile generator if available, otherwise adapt the static profile
            let targetProfile: any Geometry2D
            if let generator = profileGenerator {
                targetProfile = generator(edgeAngle)
            } else {
                targetProfile = Self.adaptProfile(shape, from: referenceAngle, to: edgeAngle)
            }

            // Measure the adapted profile to get accurate bounds
            targetProfile.measuringBounds { adaptedShape, adaptedBounds in
                let negativeShape: any Geometry2D
                if Swift.abs((edgeAngle - 90°).degrees) < 0.1 {
                    // Use rectangle for 90° (original behavior)
                    negativeShape = Rectangle(adaptedBounds.size)
                        .aligned(at: .max)
                        .subtracting { adaptedShape }
                } else {
                    // Use wedge for other angles
                    let wedgeSize = max(adaptedBounds.size.x, adaptedBounds.size.y) * 3
                    negativeShape = Self.wedge(angle: edgeAngle, size: wedgeSize)
                        .subtracting { adaptedShape }
                }

                reader(negativeShape, adaptedBounds.size)
            } empty: {
                reader(Empty(), .zero)
            }
        } empty: {
            reader(Empty(), .zero)
        }
    }

    /// Adapts a profile from one edge angle to another.
    ///
    /// This scales and shears the profile to fit the target angle while maintaining
    /// the same visual "depth" into the material.
    ///
    static func adaptProfile(_ profile: any Geometry2D, from sourceAngle: Angle, to targetAngle: Angle) -> any Geometry2D {
        guard Swift.abs((sourceAngle - targetAngle).degrees) > 0.1 else {
            return profile
        }

        // For angle adaptation, we scale the profile to maintain consistent depth
        // The key insight: depth along the bisector should remain constant
        //
        // For a 90° corner, the bisector is at 45°
        // For a θ° corner, the bisector is at θ/2
        //
        // Scale factor to maintain bisector depth: sin(sourceAngle/2) / sin(targetAngle/2)

        let sourceHalf = sourceAngle / 2
        let targetHalf = targetAngle / 2

        let scaleFactor = sin(sourceHalf) / sin(targetHalf)

        // We also need to rotate and shear to align with the new corner
        // The profile is defined in a coordinate system where:
        // - Negative X is into face 1
        // - Positive Y is into face 2 (perpendicular to face 1 for 90°)
        //
        // For other angles, we need to shear so Y aligns with face 2's direction

        let shearAngle = targetAngle - 90°

        return profile
            .scaled(scaleFactor)
            .sheared(.y, angle: shearAngle)
    }

    func followingEdge(of shape: any Geometry2D, type: EnvironmentValues.Operation, edgeAngle: Angle = 90°) -> any Geometry3D {
        readingNegativeShape(for: edgeAngle) { negativeShape, profileSize in
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
