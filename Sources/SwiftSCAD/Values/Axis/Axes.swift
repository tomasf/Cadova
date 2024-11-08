import Foundation

/// A set of cartesian axes in two dimensions (X and/or Y)
public typealias Axes2D = Set<Axis2D>

public extension Axes2D {
    init(x: Bool, y: Bool) {
        self = Set([
            x ? .x : nil,
            y ? .y : nil,
        ].compactMap { $0 })
    }

    var inverted: Self {
        .all.subtracting(self)
    }
    
    static let x: Self = [.x]
    static let y: Self = [.y]

    static let none: Self = []
    static let xy: Self = [.x, .y]
    static let all: Self = [.x, .y]
}

/// A set of cartesian axes in three dimensions (X, Y and/or Z)
public typealias Axes3D = Set<Axis3D>

public extension Axes3D {
    init(x: Bool, y: Bool, z: Bool) {
        self = Set([
            x ? .x : nil,
            y ? .y : nil,
            z ? .z : nil
        ].compactMap { $0 })
    }

    var inverted: Self {
        .all.subtracting(self)
    }

    static let x: Self = [.x]
    static let y: Self = [.y]
    static let z: Self = [.z]

    static let none: Self = []
    static let xy: Self = [.x, .y]
    static let xz: Self = [.x, .z]
    static let yz: Self = [.y, .z]
    static let xyz: Self = [.x, .y, .z]
    static let all: Self = .xyz
}
