import Foundation

/// A rectangular cuboid shape
public struct Box: CoreGeometry3D {
	let size: Vector3D
	let center: Axes3D

    /// Create a Box
    /// - Parameters:
    ///   - size: The size of the box expressed as a vector
    ///   - center: Which axes of the box to center on the origin
    ///
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
