import Foundation

// Cadova Geometry Protocols
// Geometry: Base
//   LeafGeometry: For concrete geometry without children, e.g. Circle, Box, Text
//   CombinedGeometry: Geometry containing multiple children, e.g. Union, Difference
//   Shape: User-facing

/// Two-dimensional geometry.
/// Don't conform your types to this protocol directly; instead, use `Shape2D` and implement its `body` property.
public protocol Geometry2D {
    typealias D = D2
    typealias Output = Cadova.GeometryResult<D>

    func evaluated(in environment: EnvironmentValues) -> Output
}

/// Three-dimensional geometry
/// Don't conform your types to this protocol directly; instead, use `Shape3D` and implement its `body` property.
public protocol Geometry3D {
    typealias D = D3
    typealias Output = Cadova.GeometryResult<D>

    func evaluated(in environment: EnvironmentValues) -> Output
}

public typealias GeometryBuilder3D = ArrayBuilder<any Geometry3D>
public typealias GeometryBuilder2D = ArrayBuilder<any Geometry2D>
