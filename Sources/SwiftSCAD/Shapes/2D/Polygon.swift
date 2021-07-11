import Foundation

public struct Polygon: CoreGeometry2D {
	public let points: [Vector2D]

	public init(_ points: [Vector2D]) {
		self.points = points
	}

	func call(in environment: Environment) -> SCADCall {
		return SCADCall(
			name: "polygon",
			params: ["points": points]
		)
	}
}
