import Foundation

internal protocol LinearInterpolation {
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self
}

extension Transform2D: LinearInterpolation {}
extension Transform3D: LinearInterpolation {}

extension Vector2D: LinearInterpolation {
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self {
        from + (to - from) * factor
    }
}

extension Vector3D: LinearInterpolation {
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self {
        from + (to - from) * factor
    }
}
