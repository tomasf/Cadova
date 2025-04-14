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

public extension Geometry2D {
    // When using `Geometry2D.offset` with the `LineJoinStyle.miter` style, this value sets
    // the maximum in multiples of the offset amount that vertices can be extended from their
    // original positions before a square shape is applied.
    func usingMiterLimit(_ limit: Double) -> Geometry2D {
        withEnvironment { $0.withMiterLimit(limit) }
    }
}

public extension Geometry3D {
    func usingMiterLimit(_ limit: Double) -> Geometry3D {
        withEnvironment { $0.withMiterLimit(limit) }
    }
}
