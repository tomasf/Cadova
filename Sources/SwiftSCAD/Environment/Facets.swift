import Foundation

private func facetModification(_ facets: Environment.Facets, body: Geometry, environment: Environment) -> SCADCall {
	let variables: [String: SCADValue]

	switch facets {
	case .fixed (let count):
		variables = ["$fn": count]
	case .dynamic (let minAngle, let minSize):
		variables = ["$fa": minAngle, "$fs": minSize, "$fn": 0]
	}

	let newEnvironment = environment.withFacets(facets)

	return SCADCall(name: "let", params: variables, body: body)
}


struct SetFacets3D: CoreGeometry3D {
	let facets: Environment.Facets
	let body: Geometry3D

	func call(in environment: Environment) -> SCADCall {
		facetModification(facets, body: body, environment: environment)
	}
}

public extension Geometry3D {
	func withFacets(minAngle: Angle, minSize: Double) -> Geometry3D {
		SetFacets3D(facets: .dynamic(minAngle: minAngle, minSize: minSize), body: self)
	}

	func withFacets(count: Int) -> Geometry3D {
		SetFacets3D(facets: .fixed(count), body: self)
	}

	func withDefaultFacets() -> Geometry3D {
		SetFacets3D(facets: .defaults, body: self)
	}
}


struct SetFacets2D: CoreGeometry2D {
	let facets: Environment.Facets
	let body: Geometry2D

	func call(in environment: Environment) -> SCADCall {
		facetModification(facets, body: body, environment: environment)
	}
}

public extension Geometry2D {
	func withFacets(minAngle: Angle, minSize: Double) -> Geometry2D {
		SetFacets2D(facets: .dynamic(minAngle: minAngle, minSize: minSize), body: self)
	}

	func withFacets(count: Int) -> Geometry2D {
		SetFacets2D(facets: .fixed(count), body: self)
	}

	func withDefaultFacets() -> Geometry2D {
		SetFacets2D(facets: .defaults, body: self)
	}
}
