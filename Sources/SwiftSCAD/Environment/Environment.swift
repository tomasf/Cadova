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
	}
}
