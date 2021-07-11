import Foundation

public struct Box: CoreGeometry3D {
	public let size: Vector3D
	public let center: Axes3D

	public init(_ size: Vector3D, center: Axes3D = []) {
		self.size = size
		self.center = center
	}

	func call(in environment: Environment) -> SCADCall {
		let cube = SCADCall(
			name: "cube",
			params: ["size": size],
			body: nil
		)

		guard !center.isEmpty else {
			return cube
		}

		return SCADCall(
			name: "translate",
			params: ["v": (size / -2).setting(axes: center.inverted, to: 0)],
			body: cube
		)
	}
}
