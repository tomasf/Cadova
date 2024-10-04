import Foundation
import SwiftSCAD

infix operator ≈
protocol ApproximatelyEquatable {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool
}

extension Double: ApproximatelyEquatable {
    static func ≈(lhs: Self, rhs: Self) -> Bool {
        abs(lhs - rhs) < 0.0001
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
    static var tolerance: Double { 0.001 }

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
