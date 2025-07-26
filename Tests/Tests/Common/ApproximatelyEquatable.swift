import Foundation
@testable import Cadova

infix operator ≈: ComparisonPrecedence

protocol ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool
}

extension ApproximatelyEquatable {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.equals(rhs, within: 1e-3)
    }
}

extension Double: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        Swift.abs(self - other) < tolerance
    }
}

extension Optional: ApproximatelyEquatable where Wrapped: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case (.none, .none): true
        case (.none, .some), (.some, .none): false
        case (.some(let a), .some(let b)): a.equals(b, within: tolerance)
        }
    }
}

extension Collection where Element: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.count == other.count
        && self.indices.allSatisfy { self[$0].equals(other[$0], within: tolerance) }
    }
}

extension Vector2D: ApproximatelyEquatable {}
extension Vector3D: ApproximatelyEquatable {}
extension Array: ApproximatelyEquatable where Element: ApproximatelyEquatable {}

extension Angle: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        degrees.equals(other.degrees, within: tolerance)
    }
}

extension BoundingBox: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.minimum.equals(other.minimum, within: tolerance) && self.maximum.equals(other.maximum, within: tolerance)
    }
}

extension BezierPath: ApproximatelyEquatable where V: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.startPoint ≈ other.startPoint && self.curves ≈ other.curves
    }
}

extension BezierCurve: ApproximatelyEquatable where V: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.controlPoints ≈ other.controlPoints
    }
}

extension Direction: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.unitVector.equals(other.unitVector, within: tolerance)
    }
}
