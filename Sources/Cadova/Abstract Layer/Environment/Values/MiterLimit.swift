import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.MiterLimit")
    static private let minimum = 2.0

    var miterLimit: Double {
        get { self[Self.environmentKey] as? Double ?? Self.minimum }
        set { self[Self.environmentKey] = max(newValue, Self.minimum) }
    }

    func withMiterLimit(_ limit: Double) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: max(limit, Self.minimum))
    }
}

public extension Geometry {
    /// Sets the miter limit for offset operations using mitered joins.
    ///
    /// When applying an offset with `.miter` as the `LineJoinStyle`, sharp corners may be extended
    /// significantly, especially at narrow angles. The miter limit constrains how far those corners
    /// can protrude by capping the extension to a multiple of the offset distance.
    ///
    /// If the miter limit is exceeded, the join style will fall back to a beveled corner (effectively
    /// creating a flat cut-off).
    ///
    /// - Parameter limit: The maximum allowed extension, expressed as a multiple of the offset amount.
    ///   For example, a limit of `2.0` means corners can extend up to twice the offset distance.
    /// - Returns: A modified geometry that uses the specified miter limit during offset operations.
    func usingMiterLimit(_ limit: Double) -> D.Geometry {
        withEnvironment { $0.withMiterLimit(limit) }
    }
}
