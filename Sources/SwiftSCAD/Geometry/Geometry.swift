import Foundation

public protocol Geometry: SCADFormattable {
	func scadString(in environment: Environment) -> String
}

public protocol Geometry3D: Geometry {}
public protocol Geometry2D: Geometry {}


public struct Empty: Geometry3D, Geometry2D {
	public init() {}
	public func scadString(in environment: Environment) -> String {
		""
	}
}

protocol CoreGeometry3D: Geometry3D {
	func call(in environment: Environment) -> SCADCall
}

extension CoreGeometry3D {
	public func scadString(in environment: Environment) -> String {
		call(in: environment).scadString(in: environment)
	}
}

protocol CoreGeometry2D: Geometry2D {
	func call(in environment: Environment) -> SCADCall
}

extension CoreGeometry2D {
	public func scadString(in environment: Environment) -> String {
		call(in: environment).scadString(in: environment)
	}
}
