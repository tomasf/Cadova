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

        public static let min = minXminYminZ

        public static let minXminYminZ = Self(x: .min, y: .min, z: .min)
        public static let minXminYmaxZ = Self(x: .min, y: .min, z: .max)
        public static let minXmaxYminZ = Self(x: .min, y: .max, z: .min)
        public static let minXmaxYmaxZ = Self(x: .min, y: .max, z: .max)
        public static let maxXminYminZ = Self(x: .max, y: .min, z: .min)
        public static let maxXminYmaxZ = Self(x: .max, y: .min, z: .max)
        public static let maxXmaxYminZ = Self(x: .max, y: .max, z: .min)
        public static let maxXmaxYmaxZ = Self(x: .max, y: .max, z: .max)

        public static func max(_ maxAxes: Axes3D) {
            self.init(
                x: maxAxes ~= .x ? .max : .min,
                y: maxAxes ~= .y ? .max : .min,
                z: maxAxes ~= .z ? .max : .min
            )
        }

        internal var maxAxes: Axes3D {[
            x == .max ? .x : .none,
            y == .max ? .y : .none,
            z == .max ? .z : .none
        ]}
    }
}

public extension Set<Box.Corner> {
    // Vertical (Z) edges
    static let minXminY: Self = [.minXminYminZ, .minXminYmaxZ]
    static let minXmaxY: Self = [.minXmaxYminZ, .minXmaxYmaxZ]
    static let maxXminY: Self = [.maxXminYminZ, .maxXminYmaxZ]
    static let maxXmaxY: Self = [.maxXmaxYminZ, .maxXmaxYmaxZ]

    // Side (Y) edges
    static let minXminZ: Self = [.minXminYminZ, .minXmaxYminZ]
    static let minXmaxZ: Self = [.minXminYmaxZ, .minXmaxYmaxZ]
    static let maxXminZ: Self = [.maxXminYminZ, .maxXmaxYminZ]
    static let maxXmaxZ: Self = [.maxXminYmaxZ, .maxXmaxYmaxZ]

    // Horizontal (X) edges
    static let minYminZ: Self = [.minXminYminZ, .maxXminYminZ]
    static let minYmaxZ: Self = [.minXminYmaxZ, .maxXminYmaxZ]
    static let maxYminZ: Self = [.minXmaxYminZ, .maxXmaxYminZ]
    static let maxYmaxZ: Self = [.minXmaxYmaxZ, .maxXmaxYmaxZ]
}
