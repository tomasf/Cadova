import Foundation

/// Any geometry, 2D or 3D
public protocol Geometry: SCADFormattable {
    func scadString(in environment: Environment) -> String
}

/// Two-dimensional geometry
public protocol Geometry2D: Geometry {}


/// Three-dimensional geometry
public protocol Geometry3D: Geometry {}
