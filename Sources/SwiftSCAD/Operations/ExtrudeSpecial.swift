import Foundation

public enum ExtrusionZSides {
	case top
	case bottom
	case both
}

public extension Geometry2D {
	private func extruded(height: Double, topRadius radius: Double, layerHeight: Double) -> Geometry3D {
		return ForEach(stride(from: 0.0, through: radius, by: layerHeight)) { z in
			self
				.offset(amount: (Angle.asin(z / radius).cos - 1) * radius, style: .round)
				.extruded(height: height - radius + z)
		}
	}

	private func extruded(height: Double, topChamferSize chamferSize: Double, layerHeight: Double) -> Geometry3D {
		return ForEach(stride(from: 0.0, through: chamferSize, by: layerHeight)) { z in
			self
				.offset(amount: -z, style: .round)
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
