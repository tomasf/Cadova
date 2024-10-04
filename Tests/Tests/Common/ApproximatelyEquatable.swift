import Foundation
import SwiftSCAD

infix operator ≈: ComparisonPrecedence

protocol ApproximatelyEquatable {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool
}

extension Double: ApproximatelyEquatable {
    static func ≈(lhs: Self, rhs: Self) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

extension Optional: ApproximatelyEquatable where Wrapped: ApproximatelyEquatable {
    static func ≈(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): true
        case (.none, .some), (.some, .none): false
        case (.some(let a), .some(let b)): a ≈ b
        }
    }
}

extension Collection where Element: ApproximatelyEquatable {
    static func ≈(lhs: Self, rhs: Self) -> Bool {
        lhs.count == rhs.count
        && lhs.indices.allSatisfy { lhs[$0] ≈ rhs[$0] }
    }
}

extension Array: ApproximatelyEquatable where Element: ApproximatelyEquatable {}


extension Vector {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.elements ≈ rhs.elements
    }
}

extension Vector2D: ApproximatelyEquatable {}
extension Vector3D: ApproximatelyEquatable {}

extension Angle: ApproximatelyEquatable {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.radians ≈ rhs.radians
    }
}

extension BoundingBox: ApproximatelyEquatable {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.minimum ≈ rhs.minimum && lhs.maximum ≈ rhs.maximum
    }
}
