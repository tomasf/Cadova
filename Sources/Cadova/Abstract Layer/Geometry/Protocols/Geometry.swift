import Foundation

public protocol Geometry<D>: Sendable {
    associatedtype D: Dimensionality
    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult
}

/// Two-dimensional geometry.
/// Don't conform your types to this protocol directly; instead, use `Shape2D` and implement its `body` property.
public typealias Geometry2D = Geometry<D2>

/// Three-dimensional geometry
/// Don't conform your types to this protocol directly; instead, use `Shape3D` and implement its `body` property.
public typealias Geometry3D = Geometry<D3>


public typealias GeometryBuilder2D = GeometryBuilder<D2>
public typealias GeometryBuilder3D = GeometryBuilder<D3>
