import Foundation

// SwiftSCAD Geometry Protocols
// Geometry: Base
//   LeafGeometry: For concrete geometry without children, e.g. Circle, Box, Text
//   CombinedGeometry: Geometry containing multiple children, e.g. Union, Difference, MinkowskiSum
//   TransformedGeometry: Single-child wrapper that applies a transform, e.g. Rotate, Translate
//   WrappedGeometry: Generic single-child wrapper
//   ExtrusionGeometry: 3D wrapper for 2D child
//   Shape: User-facing

/// Two-dimensional geometry.
/// Don't conform your types to this protocol directly; instead, use `Shape2D` and implement its `body` property.
public protocol Geometry2D {
    typealias Output = Output2D
    typealias Bounds = Boundary<Vector2D>

    func evaluated(in environment: Environment) -> Output
}

/// Three-dimensional geometry
/// Don't conform your types to this protocol directly; instead, use `Shape3D` and implement its `body` property.
public protocol Geometry3D {
    typealias Output = Output3D
    typealias Bounds = Boundary<Vector3D>

    func evaluated(in environment: Environment) -> Output
}

public typealias GeometryBuilder3D = ArrayBuilder<any Geometry3D>
public typealias GeometryBuilder2D = ArrayBuilder<any Geometry2D>
