import Foundation

public extension Box {
    struct Side: Sendable {
        let axis: Axis3D
        let axisDirection: AxisDirection

        public init(axis: Axis3D, towards direction: AxisDirection) {
            self.axis = axis
            self.axisDirection = direction
        }

        public var direction: Vector3D {
            axis.directionVector(axisDirection)
        }

        public static let minX = Self(axis: .x, towards: .negative)
        public static let maxX = Self(axis: .x, towards: .positive)
        public static let minY = Self(axis: .y, towards: .negative)
        public static let maxY = Self(axis: .y, towards: .positive)
        public static let minZ = Self(axis: .z, towards: .negative)
        public static let maxZ = Self(axis: .z, towards: .positive)

        public static let left = minX
        public static let right = maxX
        public static let front = minY
        public static let back = maxY
        public static let bottom = minZ
        public static let top = maxZ
    }
}
