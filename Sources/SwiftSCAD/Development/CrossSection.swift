import Foundation

struct CrossSection: Shape {
	let axis: Axis3D
	let positive: Bool
	let offset: Double
	let content: Geometry3D

	var body: Geometry3D {
		let universeLength = 1000.0
		let rotation: [Angle]

		switch axis {
		case .x: rotation = [0, 0, positive ? 0 : 180]
		case .y: rotation = [0, 0, positive ? 90 : -90]
		case .z: rotation = [0, positive ? -90 : 90, 0]
		}

		return content.subtracting {
			Box([universeLength, universeLength, universeLength], center: [.y, .z])
				.translate(x: positive ? offset : -offset)
				.rotate(rotation)
				.color(named: .orangeRed)
		}
	}
}

public extension Geometry3D {
	func crossSection(axis: Axis3D, offset: Double = 0, invert: Bool = false) -> Geometry3D {
		CrossSection(axis: axis, positive: invert, offset: offset, content: self)
	}
}
