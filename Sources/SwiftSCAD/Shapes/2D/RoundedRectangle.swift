import Foundation

public struct RoundedRectangle: Shape2D {
	let radii: CornerRadii
	let size: Vector2D
	let center: Axes2D

	public init(_ size: Vector2D, cornerRadii: [Double], center: Axes2D = []) {
		self.size = size
		self.radii = [cornerRadii[0], cornerRadii[1], cornerRadii[2], cornerRadii[3]]
		self.center = center

		precondition(
			radii.bottomLeft + radii.bottomRight <= size.x
				&& radii.topLeft + radii.topRight <= size.x
				&& radii.topLeft + radii.bottomLeft <= size.y
				&& radii.topRight + radii.bottomRight <= size.y,
			"Rounded rectangle corners are too big to fit within rectangle size"
		)
	}

	public init(_ size: Vector2D, cornerRadius: Double, center: Axes2D = []) {
		self.init(size, cornerRadii: [cornerRadius, cornerRadius, cornerRadius, cornerRadius], center: center)
	}

	public init(_ size: Vector2D, bottomLeft: Double, bottomRight: Double, topRight: Double, topLeft: Double, center: Axes2D = []) {
		self.init(size, cornerRadii: [bottomLeft, bottomRight, topRight, topLeft], center: center)
	}

	@UnionBuilder public var body: Geometry2D {
		let centerTranslation = (size / -2).setting(axes: center.inverted, to: 0)

		Union {
			Corner(angleOffset: 90°, radius: radii.topLeft)
				.translated(x: radii.topLeft, y: size.y - radii.topLeft)

			Corner(angleOffset: 0°, radius: radii.topRight)
				.translated(x: size.x - radii.topRight, y: size.y - radii.topRight)

			Corner(angleOffset: 180°, radius: radii.bottomLeft)
				.translated(x: radii.bottomLeft, y: radii.bottomLeft)

			Corner(angleOffset: 270°, radius: radii.bottomRight)
				.translated(x: size.x - radii.bottomRight, y: radii.bottomRight)

			Polygon([
				[radii.topLeft, size.y], [size.x - radii.topRight, size.y],
				[size.x, size.y - radii.topRight], [size.x, radii.bottomRight],
				[size.x - radii.bottomRight, 0], [radii.bottomLeft, 0],
				[0, radii.bottomLeft], [0, size.y - radii.topLeft]
			])
		}
		.translated(centerTranslation)
	}

	public struct CornerRadii: ExpressibleByArrayLiteral {
		public let bottomLeft: Double
		public let bottomRight: Double
		public let topRight: Double
		public let topLeft: Double

		public typealias ArrayLiteralElement = Double
		public init(arrayLiteral elements: Double...) {
			precondition(elements.count == 4, "CornerRadii needs 4 radii")
			bottomLeft = elements[0]
			bottomRight = elements[1]
			topRight = elements[2]
			topLeft = elements[3]
		}
	}

	private struct Corner: Shape2D {
		let angleOffset: Angle
		let radius: Double

		var body: Geometry2D {
			if radius > .ulpOfOne {
				return Arc(range: 0°..<90°, radius: radius)
					.rotated(angleOffset)
			} else {
				return Rectangle([0.001, 0.001])
					.rotated(angleOffset + 180°)
			}
		}
	}
}
