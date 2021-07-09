import Foundation

public struct Teardrop: Shape2D {
	public let style: Style
	public let angle: Angle
	public let diameter: Double

	public init(diameter: Double, angle: Angle = 45, style: Style = .full) {
		precondition(angle > 0 && angle < 90, "Angle must be between 0 and 90 degrees")
		self.diameter = diameter
		self.angle = angle
		self.style = style
	}

	public var body: Geometry2D {
		let x = angle.cos * diameter/2
		let y = angle.sin * diameter/2
		let diagonal = diameter / angle.sin

		let base = Union {
			Circle(diameter: diameter)

			Rectangle([diagonal, diagonal])
				.rotate(-angle)
				.translate(x: -x, y: y)
				.intersection {
					Rectangle([diagonal, diagonal])
						.rotate(angle + 90)
						.translate(x: x, y: y)
				}
		}

		if style == .bridged {
			return base.intersection {
				Rectangle([diameter, diameter], center: .xy)
			}
		} else {
			return base
		}
	}

	public enum Style {
		case full
		case bridged
	}
}
