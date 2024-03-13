import Foundation

public protocol AffineTransform {
    associatedtype Vector: SwiftSCAD.Vector
    associatedtype Rotation

    static var identity: Self { get }

    init(_ values: [[Double]])
    subscript(_ row: Int, _ column: Int) -> Double { get set }
    func setting(row: Int, column: Int, to: Double) -> Self
    func applying(_ function: (_ row: Int, _ column: Int, _ value: Double) -> Double) -> Self
    static func linearInterpolation(_ from: Self, _ to: Self, factor: Double) -> Self

    var inverse: Self { get }
    func concatenated(with: Self) -> Self
    func apply(to point: Vector) -> Vector

    static func translation(_ v: Vector) -> Self
    static func scaling(_ v: Vector) -> Self
    static func rotation(_ r: Rotation) -> Self

    init(_ transform3d: AffineTransform3D)
}
