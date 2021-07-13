import Foundation

public protocol Shape3D: Geometry3D {
	@UnionBuilder var body: Geometry3D { get }
}

public extension Shape3D {
	func scadString(in environment: Environment) -> String {
		body.scadString(in: environment)
	}
}


public protocol Shape2D: Geometry2D {
	@UnionBuilder var body: Geometry2D { get }
}

public extension Shape2D {
	func scadString(in environment: Environment) -> String {
		body.scadString(in: environment)
	}
}
