import Foundation

public protocol AffineTransform: Sendable {
    associatedtype Vector: SwiftSCAD.Vector
    associatedtype Rotation

    static var identity: Self { get }

    var inverse: Self { get }
    func concatenated(with: Self) -> Self
    func apply(to point: Vector) -> Vector
    func mapValues(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> Self
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self

    init(_ values: [[Double]])
    subscript(_ row: Int, _ column: Int) -> Double { get set }

    static func translation(_ v: Vector) -> Self
    static func scaling(_ v: Vector) -> Self
    static func rotation(_ r: Rotation) -> Self
    
    func translated(_ v: Vector) -> Self
    func scaled(_ v: Vector) -> Self
    func rotated(_ rotation: Rotation) -> Self

    init(_ transform3d: AffineTransform3D)
}
