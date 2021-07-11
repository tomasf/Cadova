import Foundation

public struct Circle: CoreGeometry2D {
	public let diameter: Double

	public init(diameter: Double) {
		self.diameter = diameter
	}

	public init(radius: Double) {
		self.diameter = radius * 2
	}

	func call(in environment: Environment) -> SCADCall {
		SCADCall(
			name: "circle",
			params: ["d": diameter]
		)
	}
}
