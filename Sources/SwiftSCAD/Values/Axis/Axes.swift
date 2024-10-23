import Foundation

public protocol Axes {
    associatedtype Axis: SwiftSCAD.Axis

    init(axis: Axis)
    func contains(axis: Axis) -> Bool
    var inverted: Self { get }
}

/// A set of cartesian axes in two dimensions (X and/or Y)

public struct Axes2D: Axes, OptionSet, Hashable, Sendable {
    public typealias Axis = Axis2D

    public let rawValue: Int
    public static let x = Axes2D(rawValue: 1 << 0)
    public static let y = Axes2D(rawValue: 1 << 1)

    public static let none: Axes2D = []
    public static let xy: Axes2D = [.x, .y]
    public static let all: Axes2D = [.x, .y]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Create an axis set from a single Axis2D
    /// - Parameter axis: The axis to represent

    public init(axis: Axis2D) {
        self.init(rawValue: 1 << axis.rawValue)
    }

    /// The axes *not* contained in this set

    public var inverted: Axes2D {
        Axes2D(rawValue: (~rawValue) & 0x3)
    }

    public func contains(axis: Axis2D) -> Bool {
        contains(Self(axis: axis))
    }
}


/// A set of cartesian axes in three dimensions (X, Y and/or Z)

public struct Axes3D: Axes, OptionSet, Hashable, Sendable {
    public typealias Axis = Axis3D

    public let rawValue: Int
    public static let x = Axes3D(rawValue: 1 << 0)
    public static let y = Axes3D(rawValue: 1 << 1)
    public static let z = Axes3D(rawValue: 1 << 2)

    public static let none: Axes3D = []
    public static let xy: Axes3D = [.x, .y]
    public static let xz: Axes3D = [.x, .z]
    public static let yz: Axes3D = [.y, .z]
    public static let xyz: Axes3D = [.x, .y, .z]
    public static let all: Axes3D = .xyz

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Create an axis set from a single Axis3D
    /// - Parameter axis: The axis to represent

    public init(axis: Axis3D) {
        self.init(rawValue: 1 << axis.rawValue)
    }

    /// The axes *not* contained in this set

    public var inverted: Axes3D {
        Axes3D(rawValue: (~rawValue) & 0x7)
    }

    public func contains(axis: Axis3D) -> Bool {
        contains(Self(axis: axis))
    }
}

extension Axes2D: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[" + Axis2D.allCases.compactMap {
            contains(axis: $0) ? String(describing: $0) : nil
        }.joined(separator: ",") + "]"
    }
}

extension Axes3D: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[" + Axis3D.allCases.compactMap {
            contains(axis: $0) ? String(describing: $0) : nil
        }.joined(separator: ",") + "]"
    }
}

