import Foundation

public struct RoundedRectangle: Shape2D {
	private let radii: CornerRadii
	let size: Vector2D
	let center: Axes2D
	let cornerStyle: CornerStyle

	internal init(_ size: Vector2D, cornerStyle: CornerStyle = .circular, radii: CornerRadii, center: Axes2D) {
		self.size = size
		self.radii = radii
		self.center = center
		self.cornerStyle = cornerStyle

		precondition(
			radii.bottomLeft + radii.bottomRight <= size.x
			&& radii.topLeft + radii.topRight <= size.x
			&& radii.topLeft + radii.bottomLeft <= size.y
			&& radii.topRight + radii.bottomRight <= size.y,
			"Rounded rectangle corners are too big to fit within rectangle size"
		)
	}

	public init(_ size: Vector2D, style: CornerStyle = .circular, cornerRadii: [Double], center: Axes2D = []) {
		self.init(size, cornerStyle: style, radii: [cornerRadii[0], cornerRadii[1], cornerRadii[2], cornerRadii[3]], center: center)
	}

	public init(_ size: Vector2D, style: CornerStyle = .circular, cornerRadius: Double, center: Axes2D = []) {
		self.init(size, style: style, cornerRadii: [cornerRadius, cornerRadius, cornerRadius, cornerRadius], center: center)
	}

	public init(_ size: Vector2D, style: CornerStyle = .circular, bottomLeft: Double = 0, bottomRight: Double = 0, topRight: Double = 0, topLeft: Double = 0, center: Axes2D = []) {
		self.init(size, style: style, cornerRadii: [bottomLeft, bottomRight, topRight, topLeft], center: center)
	}

	@UnionBuilder2D public var body: Geometry2D {
		let centerTranslation = (size / -2).setting(axes: center.inverted, to: 0)

		Union {
			Corner(rotation: 90°, radius: radii.topLeft, style: cornerStyle)
				.translated(x: radii.topLeft, y: size.y - radii.topLeft)

			Corner(rotation: 0°, radius: radii.topRight, style: cornerStyle)
				.translated(x: size.x - radii.topRight, y: size.y - radii.topRight)

			Corner(rotation: 180°, radius: radii.bottomLeft, style: cornerStyle)
				.translated(x: radii.bottomLeft, y: radii.bottomLeft)

			Corner(rotation: 270°, radius: radii.bottomRight, style: cornerStyle)
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

	public enum CornerStyle {
		case circular
		case squircular
	}

	internal struct CornerRadii: ExpressibleByArrayLiteral {
		public let bottomLeft: Double
		public let bottomRight: Double
		public let topRight: Double
		public let topLeft: Double

		typealias ArrayLiteralElement = Double
		init(arrayLiteral elements: Double...) {
			precondition(elements.count == 4, "CornerRadii needs 4 radii")
			bottomLeft = elements[0]
			bottomRight = elements[1]
			topRight = elements[2]
			topLeft = elements[3]
		}

		init(_ value: Double) {
			self.init(arrayLiteral: value, value, value, value)
		}
	}

	private struct Corner: Shape2D {
		let rotation: Angle
		let radius: Double
		let style: CornerStyle

		var body: Geometry2D {
			if radius > .ulpOfOne {
				if style == .circular {
					Arc(range: 0°..<90°, radius: radius)
						.rotated(rotation)
				} else {
					SquircleCorner(radius: radius)
						.rotated(rotation)
				}
			}
		}
	}

	private struct SquircleCorner: Shape2D {
		let radius: Double

		var body: Geometry2D {
			EnvironmentReader2D { environment in
				let facets = environment.facets.facetCount(circleRadius: radius)
				let radius4th = pow(radius, 4.0)

				let points = [.zero] + (0...facets).map { facet -> Vector2D in
					let x = cos(.pi / 2.0 / Double(facets) * Double(facet)) * radius
					let y = pow(radius4th - pow(x, 4.0), 0.25)
					return Vector2D(x, y)
				} + [.zero]

				return Polygon(points)
			}
		}
	}
}
