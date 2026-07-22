import Foundation

/// A profile used to modify the edge of a 3D shape, such as for chamfers or fillets, with
/// independent horizontal and vertical dimensions anchored to a fixed frame.
///
/// The profile is defined in 2D, where:
/// - The X axis is horizontal; negative X points inward, positive X outward from the edge
/// - The Y axis is vertical; positive Y points outward from the edge face
///
/// This fixed frame makes `EdgeProfile` suited to locations with a known orientation,
/// such as extrusion caps, box edges, and print-orientation-aware profiles like
/// `overhangFillet(radius:)`. For edges of unknown or varying orientation — such as those found
/// on an arbitrary model with `readingEdges(matching:)` — use the mirror-symmetric ``EdgeShape``
/// instead, which adapts to any dihedral angle and handles cut-vs-fill automatically.
///
public struct EdgeProfile: Sendable {
    public let profile: any Geometry2D

    /// Creates a new edge profile.
    /// - Parameter profile: A 2D geometry builder describing the profile cross-section. The profile is automatically
    ///   aligned so that its bottom-right corner is at the origin.
    ///
    public init(@GeometryBuilder2D profile: @Sendable @escaping () -> any Geometry2D) {
        self.profile = profile().aligned(at: .max)
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
}
