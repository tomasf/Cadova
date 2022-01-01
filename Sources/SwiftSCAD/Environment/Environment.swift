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

private struct EnvironmentReader2D: Geometry2D {
	@UnionBuilder let body: (Environment) -> Geometry2D

	func scadString(in environment: Environment) -> String {
		body(environment).scadString(in: environment)
	}
}

private struct EnvironmentReader3D: Geometry3D {
	@UnionBuilder let body: (Environment) -> Geometry3D

	func scadString(in environment: Environment) -> String {
		body(environment).scadString(in: environment)
	}
}

public func EnvironmentReader(@UnionBuilder body: @escaping (Environment) -> Geometry2D) -> Geometry2D {
	EnvironmentReader2D(body: body)
}

public func EnvironmentReader(@UnionBuilder body: @escaping (Environment) -> Geometry3D) -> Geometry3D {
	EnvironmentReader3D(body: body)
}
