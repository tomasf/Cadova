import Foundation

public struct Arc: Geometry2D {
	public let range: Range<Angle>
	public let radius: Double

	public init(range: Range<Angle>, radius: Double) {
		self.range = range
		self.radius = radius
	}

	public init(range: Range<Angle>, diameter: Double) {
		self.init(range: range, radius: diameter / 2)
	}

	public func scadString(environment: Environment) -> String {
		let magnitude = range.upperBound - range.lowerBound
		let fraction = magnitude / 360°

		let circleFacets: Double

		switch environment.facets {
		case .fixed (let perRev):
			circleFacets = Double(perRev)

		case .dynamic (let minAngle, let minSize):
			let facetsFromAngle = 360.0 / minAngle
			let circumference = radius * 2 * .pi
			let facetsFromSize = circumference / minSize
			circleFacets = min(facetsFromAngle, facetsFromSize)
		}

		let facetCount = max(Int(ceil(circleFacets * fraction)), 2)
		let facetAngle = magnitude / Double(facetCount)

		let outerPoints = (0...facetCount).map { i -> Vector2D in
			let angle = range.lowerBound + facetAngle * Double(i)
			return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
		}
		let allPoints = [Vector2D.zero] + outerPoints + [Vector2D.zero]

		return Polygon(allPoints)
			.scadString(environment: environment)
	}
}
