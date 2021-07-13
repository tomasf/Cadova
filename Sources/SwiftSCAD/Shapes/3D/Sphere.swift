import Foundation

/// A sphere
///
/// The number of faces of a sphere (and its smoothness) is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``.

public struct Sphere: CoreGeometry3D {
	let diameter: Double

	public init(diameter: Double) {
		self.diameter = diameter
	}

	public init(radius: Double) {
		self.diameter = radius * 2
	}

	func call(in environment: Environment) -> SCADCall {
		return SCADCall(name: "sphere", params: ["d": diameter])
	}
}
