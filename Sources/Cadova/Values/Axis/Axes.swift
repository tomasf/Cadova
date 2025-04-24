import Foundation

/// A set of cartesian axes in two dimensions (X and/or Y)
public typealias Axes2D = Set<Axis2D>

public extension Axes2D {
    /// Creates a 2D axis set based on boolean flags for each axis.
    ///
    /// - Parameters:
    ///   - x: Include the X axis if `true`.
    ///   - y: Include the Y axis if `true`.
    init(x: Bool, y: Bool) {
        self.init(x ? .x : [], y ? .y : [])
    }
    
    /// Returns the inverse of the current axis set (i.e., all axes not included in the current set).
    var inverted: Self {
        .all.subtracting(self)
    }
    
    /// A set containing only the X axis.
    static let x: Self = [.x]
    /// A set containing only the Y axis.
    static let y: Self = [.y]
    
    /// An empty set of axes.
    static let none: Self = []
    /// A set containing both X and Y axes.
    static let xy: Self = [.x, .y]
    /// A set containing all possible 2D axes.
    static let all: Self = [.x, .y]
}

/// A set of cartesian axes in three dimensions (X, Y and/or Z)
public typealias Axes3D = Set<Axis3D>

public extension Axes3D {
    /// Creates a 3D axis set based on boolean flags for each axis.
    ///
    /// - Parameters:
    ///   - x: Include the X axis if `true`.
    ///   - y: Include the Y axis if `true`.
    ///   - z: Include the Z axis if `true`.
    init(x: Bool, y: Bool, z: Bool) {
        self.init(x ? .x : [], y ? .y : [], z ? .z : [])
    }
    
    /// Returns the inverse of the current axis set (i.e., all axes not included in the current set).
    var inverted: Self {
        .all.subtracting(self)
    }
    
    /// A set containing only the X axis.
    static let x: Self = [.x]
    /// A set containing only the Y axis.
    static let y: Self = [.y]
    /// A set containing only the Z axis.
    static let z: Self = [.z]
    
    /// An empty set of axes.
    static let none: Self = []
    /// A set containing the X and Y axes.
    static let xy: Self = [.x, .y]
    /// A set containing the X and Z axes.
    static let xz: Self = [.x, .z]
    /// A set containing the Y and Z axes.
    static let yz: Self = [.y, .z]
    /// A set containing all three axes: X, Y, and Z.
    static let xyz: Self = [.x, .y, .z]
    /// A set containing all possible 3D axes.
    static let all: Self = .xyz
}
