import Foundation

public struct Sphere: CoreGeometry3D {
	public let diameter: Double

	public init(diameter: Double) {
		self.diameter = diameter
	}

	public init(radius: Double) {
		self.diameter = radius * 2
	}

	func call(in environment: Environment) -> SCADCall {
		return SCADCall(name: "sphere", params: ["d": diameter])
	}
}
