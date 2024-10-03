import Foundation

// SwiftSCAD Geometry Protocols
// Geometry: Base
//   LeafGeometry: For concrete geometry without children, e.g. Circle, Box, Text
//   CombinedGeometry: Geometry containing multiple children, e.g. Union, Difference, MinkowskiSum
//   TransformedGeometry: Single-child wrapper that applies a transform, e.g. Rotate, Translate
//   WrappedGeometry: Generic single-child wrapper
//   Shape: User-facing

/// Two-dimensional geometry.
/// Don't conform your types to this protocol directly; instead, use `Shape2D` and implement its `body` property.
public protocol Geometry2D {
    typealias Bounds = Boundary<Vector2D>

    func codeFragment(in environment: Environment) -> CodeFragment
    func boundary(in environment: Environment) -> Bounds
    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement]
}

/// Three-dimensional geometry
/// Don't conform your types to this protocol directly; instead, use `Shape3D` and implement its `body` property.
public protocol Geometry3D {
    typealias Bounds = Boundary<Vector3D>

    func codeFragment(in environment: Environment) -> CodeFragment
    func boundary(in environment: Environment) -> Bounds
    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement]
}
