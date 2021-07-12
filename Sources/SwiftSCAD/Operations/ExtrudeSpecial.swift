import Foundation

public enum ExtrusionZSides {
	case top
	case bottom
	case both
}

public extension Geometry2D {
	@UnionBuilder private func extruded(height: Double, topRadius radius: Double, layerHeight: Double) -> Geometry3D {
		for z in stride(from: 0.0, through: radius, by: layerHeight) {
			offset(amount: (cos(asin(z / radius) as Angle) - 1) * radius, style: .round)
				.extruded(height: height - radius + z)
		}
	}

	@UnionBuilder private func extruded(height: Double, topChamferSize chamferSize: Double, layerHeight: Double) -> Geometry3D {
		for z in stride(from: 0.0, through: chamferSize, by: layerHeight) {
			offset(amount: -z, style: .round)
				.extruded(height: height - chamferSize + z)
		}
	}

	func extruded(height: Double, radius: Double, layerHeight: Double, sides: ExtrusionZSides = .top) -> Geometry3D {
		switch sides {
		case .top:
			return extruded(height: height, topRadius: radius, layerHeight: layerHeight)
		case .bottom:
			return extruded(height: height, topRadius: radius, layerHeight: layerHeight)
				.scaled(z: -1)
				.translated(z: height)
		case .both:
			return Union {
				extruded(height: height / 2, radius: radius, layerHeight: layerHeight, sides: .top)
					.translated(z: height / 2)
				extruded(height: height / 2, radius: radius, layerHeight: layerHeight, sides: .bottom)
			}
		}
	}

	func extruded(height: Double, chamferSize: Double, layerHeight: Double, sides: ExtrusionZSides = .top) -> Geometry3D {
		switch sides {
		case .top:
			return extruded(height: height, topChamferSize: chamferSize, layerHeight: layerHeight)
		case .bottom:
			return extruded(height: height, topChamferSize: chamferSize, layerHeight: layerHeight)
				.scaled(z: -1)
				.translated(z: height)
		case .both:
			return Union {
				extruded(height: height / 2, chamferSize: chamferSize, layerHeight: layerHeight, sides: .top)
					.translated(z: height / 2)
				extruded(height: height / 2, chamferSize: chamferSize, layerHeight: layerHeight, sides: .bottom)
			}
		}
	}
}
