import Foundation

public struct CylinderBridge: Shape2D {
	let topDiameter: Double
	let bottomDiameter: Double

	public init(bottomDiameter: Double, topDiameter: Double) {
		assert(bottomDiameter > topDiameter, "The bottom diameter should be larger than the top diameter")
		if topDiameter < bottomDiameter / 2.0 {
			print("Warning: Bridging where the top diameter is less than half the bottom diameter may not work optimally.")
		}
		self.bottomDiameter = bottomDiameter
		self.topDiameter = topDiameter
	}

	private func regularPolygonSideCount(inscribedDiameter: Double, circumscribedDiameter: Double) -> Double {
		.pi / acos(inscribedDiameter / circumscribedDiameter)
	}

	private var sideCount: Int {
		let target = regularPolygonSideCount(inscribedDiameter: topDiameter, circumscribedDiameter: bottomDiameter)
		return max(Int(floor(target)), 3)
	}

	public var body: Geometry2D {
		Circle(diameter: bottomDiameter)
			.subtracting {
				ForEach(0..<sideCount) { i in
					let angle = (360° / Double(sideCount)) * Double(i)
					Rectangle([bottomDiameter, bottomDiameter], center: .y)
						.translated(x: topDiameter / 2)
						.rotated(angle)
				}
			}
	}
}
