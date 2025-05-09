import Foundation

public extension Box {
    /// A type representing one of the eight corners of a 3D box.
    ///
    /// Each corner is defined by a combination of minimum or maximum positions
    /// along the X, Y, and Z axes. For example, `.minXminYminZ` refers to the
    /// corner with the smallest X, Y, and Z coordinates.
    ///
    typealias Corner = OrthogonalCorner<D3>
    typealias Corners = Set<Corner>
}

public extension Box.Corner {
    /// Creates a box corner from explicit axis directions.
    ///
    /// - Parameters:
    ///   - x: The linear direction for the X axis (`.min` or `.max`).
    ///   - y: The linear direction for the Y axis.
    ///   - z: The linear direction for the Z axis.
    ///
    init(x: LinearDirection, y: LinearDirection, z: LinearDirection) {
        self.init(axisDirections: .init(x: x, y: y, z: z))
    }

    /// The X axis direction of this corner.
    var x: LinearDirection { axisDirections[.x] }

    /// The Y axis direction of this corner.
    var y: LinearDirection { axisDirections[.y] }

    /// The Z axis direction of this corner.
    var z: LinearDirection { axisDirections[.z] }


    /// An alias for `.minXminYminZ`, the corner at the minimum X, Y, and Z.
    static let min = minXminYminZ

    /// The corner at the minimum X, Y, and Z coordinates.
    static let minXminYminZ = Self(x: .min, y: .min, z: .min)

    /// The corner at the minimum X, Y, and maximum Z coordinates.
    static let minXminYmaxZ = Self(x: .min, y: .min, z: .max)

    /// The corner at the minimum X, maximum Y, and minimum Z coordinates.
    static let minXmaxYminZ = Self(x: .min, y: .max, z: .min)

    /// The corner at the minimum X, maximum Y, and maximum Z coordinates.
    static let minXmaxYmaxZ = Self(x: .min, y: .max, z: .max)

    /// The corner at the maximum X, Y, and minimum Z coordinates.
    static let maxXminYminZ = Self(x: .max, y: .min, z: .min)

    /// The corner at the maximum X, Y, and maximum Z coordinates.
    static let maxXminYmaxZ = Self(x: .max, y: .min, z: .max)

    /// The corner at the maximum X, maximum Y, and minimum Z coordinates.
    static let maxXmaxYminZ = Self(x: .max, y: .max, z: .min)

    /// The corner at the maximum X, maximum Y, and maximum Z coordinates.
    static let maxXmaxYmaxZ = Self(x: .max, y: .max, z: .max)


    /// The front-left corner on the bottom face (minX, minY, minZ).
    static let bottomLeftFront: Self = .minXminYminZ

    /// The back-left corner on the bottom face (minX, maxY, minZ).
    static let bottomLeftBack: Self = .minXmaxYminZ

    /// The front-right corner on the bottom face (maxX, minY, minZ).
    static let bottomRightFront: Self = .maxXminYminZ

    /// The back-right corner on the bottom face (maxX, maxY, minZ).
    static let bottomRightBack: Self = .maxXmaxYminZ

    /// The front-left corner on the top face (minX, minY, maxZ).
    static let topLeftFront: Self = .minXminYmaxZ

    /// The back-left corner on the top face (minX, maxY, maxZ).
    static let topLeftBack: Self = .minXmaxYmaxZ

    /// The front-right corner on the top face (maxX, minY, maxZ).
    static let topRightFront: Self = .maxXminYmaxZ

    /// The back-right corner on the top face (maxX, maxY, maxZ).
    static let topRightBack: Self = .maxXmaxYmaxZ
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
            LinearDirection.allCases.flatMap { x in
                LinearDirection.allCases.flatMap { y in
                    LinearDirection.allCases.map { z in
                        Box.Corner(x: x, y: y, z: z)
                    }
                }
            }
        )
    }
}
