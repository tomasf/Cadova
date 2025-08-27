import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.TwistSubdivisionThreshold")
    private static let defaultThreshold = 15°

    /// The maximum angle allowed between adjacent surface segments when twisting geometry.
    ///
    /// This threshold controls how finely a 2D shape is subdivided before being extruded with twist.
    /// Lower values produce more subdivisions and smoother surfaces on the vertical walls.
    /// Higher values reduce subdivisions, which can lead to more visible faceting.
    ///
    /// A value of `0°` disables threshold‑driven subdivision of the 2D shape before extrusion.
    /// Vertical (Z) segmentation still follows segmentation settings.
    /// The default value is `15°`.
    var twistSubdivisionThreshold: Angle {
        get { self[Self.key] as? Angle ?? Self.defaultThreshold }
        set { self[Self.key] = newValue }
    }

    /// Sets the twist subdivision threshold.
    ///
    /// - Parameter threshold: The maximum angle allowed between surface segments.
    ///                        Set to `0°` to disable threshold‑driven subdivision of the 2D shape;
    ///                        vertical (Z) segmentation is unaffected and still follows
    ///                        `.withSegmentation(...)` and related settings.
    /// - Returns: A new environment with the specified twist subdivision threshold.
    func withTwistSubdivisionThreshold(_ threshold: Angle?) -> EnvironmentValues {
        setting(key: Self.key, value: threshold)
    }
}

public extension Geometry {
    /// Sets the maximum angle allowed between adjacent surface segments when twisting geometry.
    ///
    /// When a 2D shape is extruded with twist, vertical walls can become curved, especially
    /// for shapes with endpoints far from the twist origin. To build smooth surfaces in these
    /// cases, the shape must be subdivided before extrusion.
    ///
    /// This threshold controls how finely the shape is subdivided based on the angle between
    /// adjacent surface segments in the resulting 3D geometry. Lower values result in more
    /// subdivisions and smoother surfaces, while higher values reduce subdivisions, which may
    /// lead to more visible faceting.
    ///
    /// A value of `0°` disables threshold‑driven subdivision of the 2D base only.
    /// Vertical (Z) segmentation still follows `.withSegmentation(...)` and other settings.
    ///
    /// - Parameter threshold: The maximum angle between adjacent surface segments.
    ///   Set to `0°` to disable threshold‑driven subdivision of the 2D shape; vertical (Z)
    ///   segmentation is unaffected.
    /// - Returns: A new geometry with the specified twist subdivision threshold.
    func withTwistSubdivisionThreshold(_ threshold: Angle) -> D.Geometry {
        withEnvironment {
            $0.withTwistSubdivisionThreshold(threshold)
        }
    }

    /// Restores the default twist subdivision threshold.
    ///
    /// - Returns: A new geometry using the default twist subdivision threshold.
    func withDefaultTwistSubdivisionThreshold() -> D.Geometry {
        withEnvironment {
            $0.withTwistSubdivisionThreshold(nil)
        }
    }
}
