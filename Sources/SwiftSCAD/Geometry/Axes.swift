import Foundation

/// One of the axes in three dimensions

public enum Axis3D: Int {
    case x
    case y
    case z
}


/// A set of possible axes in three dimensions

public struct Axes3D: OptionSet, Hashable {
    public let rawValue: Int
    public static let x = Axes3D(rawValue: 1 << 0)
    public static let y = Axes3D(rawValue: 1 << 1)
    public static let z = Axes3D(rawValue: 1 << 2)

    public static let none: Axes3D = []
    public static let xy: Axes3D = [.x, .y]
    public static let xz: Axes3D = [.x, .z]
    public static let yz: Axes3D = [.y, .z]
    public static let all: Axes3D = [.x, .y, .z]

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
}

/// One of the axes in two dimensions

public enum Axis2D: Int {
    case x
    case y
}

/// A set of possible axes in two dimensions

public struct Axes2D: OptionSet, Hashable {
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
}
