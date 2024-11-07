import Foundation

public extension Box {
    typealias Corner = BoxCorner<Vector3D>
    typealias Corners = Set<Corner>
}

public extension Box.Corner {
    init(x: AxisDirection, y: AxisDirection, z: AxisDirection) {
        self.init(axisDirections: .init(x: x, y: y, z: z))
    }

    var x: AxisDirection { axisDirections[.x] }
    var y: AxisDirection { axisDirections[.y] }
    var z: AxisDirection { axisDirections[.z] }

    static let min = minXminYminZ

    static let minXminYminZ = Self(x: .min, y: .min, z: .min)
    static let minXminYmaxZ = Self(x: .min, y: .min, z: .max)
    static let minXmaxYminZ = Self(x: .min, y: .max, z: .min)
    static let minXmaxYmaxZ = Self(x: .min, y: .max, z: .max)
    static let maxXminYminZ = Self(x: .max, y: .min, z: .min)
    static let maxXminYmaxZ = Self(x: .max, y: .min, z: .max)
    static let maxXmaxYminZ = Self(x: .max, y: .max, z: .min)
    static let maxXmaxYmaxZ = Self(x: .max, y: .max, z: .max)
}

public extension Box.Corners {
    static let minXminYminZ: Self = [.minXminYminZ]
    static let minXminYmaxZ: Self = [.minXminYmaxZ]
    static let minXmaxYminZ: Self = [.minXmaxYminZ]
    static let minXmaxYmaxZ: Self = [.minXmaxYmaxZ]
    static let maxXminYminZ: Self = [.maxXminYminZ]
    static let maxXminYmaxZ: Self = [.maxXminYmaxZ]
    static let maxXmaxYminZ: Self = [.maxXmaxYminZ]
    static let maxXmaxYmaxZ: Self = [.maxXmaxYmaxZ]
}

public extension Box.Corners {
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

    static let none: Self = []
    static var all: Self {
        Set(
            AxisDirection.allCases.flatMap { x in
                AxisDirection.allCases.flatMap { y in
                    AxisDirection.allCases.map { z in
                        Box.Corner(x: x, y: y, z: z)
                    }
                }
            }
        )
    }
}
