import Foundation

public protocol Shape: Geometry {
    @GeometryBuilder<D> var body: any Geometry<D> { get }
}

public extension Shape {
    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: body, in: environment)
    }
}

/// A protocol defining the requirements for custom 2D shapes.
///
/// Conform to `Shape2D` to create custom types that represent 2D geometries. A conforming type must provide a `body` property, which defines the shape's geometry using geometry primitives and operations. The `Shape2D` protocol itself conforms to `Geometry2D`, ensuring that custom shapes can be used anywhere standard Cadova 2D geometries are used.
///
/// Example:
/// ```
/// struct CustomShape: Shape2D {
///     let size: Double
///
///     var body: any Geometry2D {
///         Rectangle(x: size * 2, y: size)
///     }
/// }
/// ```
public protocol Shape2D: Shape where D == D2 {
    /// The geometry content of this shape.
    ///
    /// Implement this property to define the shape's structure using Cadova's geometry primitives and operations.
    @GeometryBuilder2D var body: any Geometry2D { get }
}

/// A protocol defining the requirements for custom 3D shapes.
///
/// Conform to `Shape3D` to create custom types that represent 3D geometries. A conforming type must provide a `body` property, which defines the shape's geometry using geometry primitives and operations. The `Shape3D` protocol itself conforms to `Geometry3D`, ensuring that custom shapes can be used anywhere standard Cadova 3D geometries are used.
///
/// Example:
/// ```
/// struct CustomShape: Shape3D {
///     let size: Double
///
///     var body: any Geometry3D {
///         Box(x: size, y: size, z: size * 3)
///     }
/// }
/// ```
public protocol Shape3D: Shape where D == D3 {
    /// The geometry content of this shape.
    ///
    /// Implement this property to define the shape's structure using Cadova's geometry primitives and operations.
    @GeometryBuilder3D var body: any Geometry3D { get }
}
