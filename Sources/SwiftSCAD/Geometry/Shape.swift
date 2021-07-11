import Foundation

public protocol Shape: Geometry3D {
	@UnionBuilder var body: Geometry3D { get }
}

public extension Shape {
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
