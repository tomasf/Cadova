import Foundation

/// Any geometry, 2D or 3D

public protocol Geometry: SCADFormattable {
	func scadString(in environment: Environment) -> String
}

/// Three-dimensional geometry

public protocol Geometry3D: Geometry {}

/// Two-dimensional geometry

public protocol Geometry2D: Geometry {}


internal struct Empty: Geometry3D, Geometry2D {
	func scadString(in environment: Environment) -> String {
		";"
	}
}

protocol CoreGeometry3D: Geometry3D {
	func call(in environment: Environment) -> SCADCall
	var bodyTransform: AffineTransform { get }
}

extension CoreGeometry3D {
	public func scadString(in environment: Environment) -> String {
		let newEnvironment = environment.applyingTransform(bodyTransform)
		return call(in: newEnvironment)
			.scadString(in: newEnvironment)
	}

	var bodyTransform: AffineTransform { .identity }
}

protocol ContainerGeometry3D: Geometry3D {
    func geometry(in environment: Environment) -> Geometry3D
}

extension ContainerGeometry3D {
    public func scadString(in environment: Environment) -> String {
        geometry(in: environment).scadString(in: environment)
    }
}

protocol CoreGeometry2D: Geometry2D {
	func call(in environment: Environment) -> SCADCall
	var bodyTransform: AffineTransform { get }
}

extension CoreGeometry2D {
	public func scadString(in environment: Environment) -> String {
		let newEnvironment = environment.applyingTransform(bodyTransform)
		return call(in: newEnvironment)
			.scadString(in: newEnvironment)
	}

	var bodyTransform: AffineTransform { .identity }
}

protocol ContainerGeometry2D: Geometry2D {
    func geometry(in environment: Environment) -> Geometry2D
}

extension ContainerGeometry2D {
    public func scadString(in environment: Environment) -> String {
        geometry(in: environment).scadString(in: environment)
    }
}
