import Foundation

public struct Environment {
	public let facets: Facets

	public init(facets: Facets = .defaults) {
		self.facets = facets
	}

	public func withFacets(_ facets: Facets) -> Environment {
		return Environment(facets: facets)
	}

	public enum Facets {
		case fixed (Int)
		case dynamic (minAngle: Angle, minSize: Double)

		public static let openSCADDefaults = Facets.dynamic(minAngle: 12°, minSize: 2)
		public static let defaults = Facets.dynamic(minAngle: 2°, minSize: 0.15)

		public func facetCount(circleRadius r: Double) -> Int {
			switch self {
			case .fixed (let count):
				return max(count, 3)
				
			case .dynamic(let minAngle, let minSize):
				let angleFacets = 360° / minAngle
				let sizeFacets = r * 2 * .pi / minSize
				return Int(max(min(angleFacets, sizeFacets), 5))
			}
		}
	}
}
