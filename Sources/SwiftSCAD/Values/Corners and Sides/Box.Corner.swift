import Foundation

public extension Box {
    struct Corner: Sendable, Hashable {
        let x: AxisDirection
        let y: AxisDirection
        let z: AxisDirection

        public init(x: AxisDirection, y: AxisDirection, z: AxisDirection) {
            self.x = x
            self.y = y
            self.z = z
        }

        static let min = Self(x: .min, y: .min, z: .min)

        internal var flippedAxes: Axes3D {[
            x == .max ? .x : [],
            y == .max ? .y : [],
            z == .max ? .z : []
        ]}
    }
}

// func roundingBoxCorner(_ corner: Box.Corner, radius: Double) -> any Geometry3D
