import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .usingFacets(count: 3)
/// ```

public struct Cylinder: CoreGeometry3D {
	let height: Double
	let diameter: Double
	let topDiameter: Double?

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - diameter: The diameter of the cylinder
    ///   - height: The height of the cylinder

    public init(diameter: Double, height: Double) {
		self.diameter = diameter
		self.topDiameter = nil
		self.height = height
	}

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - radius: The radius (half diameter) of the cylinder
    ///   - height: The height of the cylinder

    public init(radius: Double, height: Double) {
		self.diameter = radius * 2
		self.topDiameter = nil
		self.height = height
	}

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - height: The height between the top and the bottom

	public init(bottomDiameter: Double, topDiameter: Double, height: Double) {
		self.diameter = bottomDiameter
		self.topDiameter = topDiameter
		self.height = height
	}

	func call(in environment: Environment) -> SCADCall {
		let params: [String: SCADValue]

		if let topDiameter = topDiameter {
			params = ["d1": diameter, "d2": topDiameter, "h": height]
		} else {
			params = ["d": diameter, "h": height]
		}

		return SCADCall(name: "cylinder", params: params)
	}
}
