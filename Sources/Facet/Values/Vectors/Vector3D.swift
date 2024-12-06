import Foundation

/// A unitless vector representing distances, sizes or scales in three dimensions
///
/// ## Examples
/// ```swift
/// let v1 = Vector3D(x: 10, y: 15, z: 5)
/// let v2: Vector3D = [10, 15, 5]
/// ```
public struct Vector3D: ExpressibleByArrayLiteral, SCADValue, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public static let zero = Vector3D(0)

    public init(_ single: Double) {
        x = single
        y = single
        z = single
    }

    public init(x: Double = 0, y: Double = 0, z: Double = 0) {
        precondition(x.isFinite, "Vector elements can't be NaN or infinite")
        precondition(y.isFinite, "Vector elements can't be NaN or infinite")
        precondition(z.isFinite, "Vector elements can't be NaN or infinite")
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.init(x: x, y: y, z: z)
    }

    public init(_ xy: Vector2D, z: Double = 0) {
        self.init(x: xy.x, y: xy.y, z: z)
    }

    public init(arrayLiteral: Double...) {
        precondition(arrayLiteral.count == 3, "Vector3D requires exactly three elements")
        self.init(x: arrayLiteral[0], y: arrayLiteral[1], z: arrayLiteral[2])
    }

    public init(_ getter: (Axis) -> Double) {
        self.init(x: getter(.x), y: getter(.y), z: getter(.z))
    }

    public var scadString: String {
        [x, y, z].scadString
    }
}

public extension Vector3D {
    subscript(_ axis: Self.Axis) -> Double {
        switch axis {
        case .x: return x
        case .y: return y
        case .z: return z
        }
    }
}

public extension Vector3D {
    var xy: Vector2D {
        .init(x: x, y: y)
    }

    var squaredEuclideanNorm: Double {
        x * x + y * y + z * z
    }
}

extension Vector3D: Vector {
    public typealias Transform = AffineTransform3D
    public typealias Axis = Axis3D
    public typealias Geometry = any Geometry3D
    public static let elementCount = 3

    public subscript(_ index: Int) -> Double {
        [x, y, z][index]
    }

    public init(elements e: [Double]) {
        self.init(e[0], e[1], e[2])
    }

    public static func min(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.min(a.x, b.x), y: Swift.min(a.y, b.y), z: Swift.min(a.z, b.z))
    }

    public static func max(_ a: Self, _ b: Self) -> Self {
        Self(x: Swift.max(a.x, b.x), y: Swift.max(a.y, b.y), z: Swift.max(a.z, b.z))
    }
}

extension Vector3D: CustomDebugStringConvertible {
    public var debugDescription: String {
        String(format: "[%g, %g, %g]", x, y, z)
    }
}
