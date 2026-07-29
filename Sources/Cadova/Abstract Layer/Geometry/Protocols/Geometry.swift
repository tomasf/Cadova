import Foundation

/// Base protocol for geometry.
///
/// To define your own shape, conform to ``Geometry2D`` or ``Geometry3D`` and implement `body`.
public protocol Geometry<D>: Sendable, Transformable where Transformed == D.Geometry, T == D.Transform {
    associatedtype D: Dimensionality
    @GeometryBuilder<D> var body: any Geometry<D> { get }
    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult
}

public extension Geometry {
    var body: any Geometry<D> {
        Empty<D>()
    }

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: body, in: environment)
    }
}

/// Two-dimensional geometry.
public typealias Geometry2D = Geometry<D2>

/// Three-dimensional geometry
public typealias Geometry3D = Geometry<D3>


/// A result builder for composing 2D geometry.
public typealias GeometryBuilder2D = GeometryBuilder<D2>

/// A result builder for composing 3D geometry.
public typealias GeometryBuilder3D = GeometryBuilder<D3>
