import Foundation

/// A right circular cylinder or a truncated right circular cone
///
/// The number of faces on the side of a Cylinder is controlled by the facet configuration. See ``Geometry3D/usingFacets(minAngle:minSize:)`` and ``Geometry3D/usingFacets(count:)``. For example, this code creates a right triangular prism:
/// ```swift
/// Cylinder(diameter: 10, height: 5)
///     .usingFacets(count: 3)
/// ```

public struct Cylinder: LeafGeometry3D {
    private let height: Double
    private let diameter: Diameter

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - diameter: The diameter of the cylinder
    ///   - height: The height of the cylinder

    public init(diameter: Double, height: Double) {
        self.diameter = .constant(diameter)
        self.height = height
    }

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - radius: The radius (half diameter) of the cylinder
    ///   - height: The height of the cylinder

    public init(radius: Double, height: Double) {
        self.init(diameter: radius * 2, height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - height: The height between the top and the bottom

    public init(bottomDiameter: Double, topDiameter: Double, height: Double) {
        self.diameter = .linear(bottom: bottomDiameter, top: topDiameter)
        self.height = height
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom radii)
    /// - Parameters:
    ///   - bottomRadius: The radius at the bottom
    ///   - topRadius: The radius at the top
    ///   - height: The height between the top and the bottom

    public init(bottomRadius: Double, topRadius: Double, height: Double) {
        self.init(bottomDiameter: bottomRadius * 2, topDiameter: topRadius * 2, height: height)
    }
}

extension Cylinder {
    private enum Diameter {
        case constant (Double)
        case linear (bottom: Double, top: Double)
    }

    public var moduleName: String { "cylinder" }
    public var moduleParameters: CodeFragment.Parameters {
        switch diameter {
        case .constant (let diameter): [
            "d": diameter,
            "h": height
        ]
        case .linear (let bottom, let top): [
            "d1": bottom,
            "d2": top,
            "h": height
        ]
        }
    }

    public func boundary(in environment: Environment) -> Bounds {
        let (bottomDiameter, topDiameter) = switch diameter {
        case .constant (let diameter): (diameter, diameter)
        case .linear (let bottom, let top): (bottom, top)
        }

        let bottom = Boundary2D.circle(radius: bottomDiameter / 2, facets: environment.facets)
        let top = Boundary2D.circle(radius: topDiameter / 2, facets: environment.facets)
        return .union(
            bottom.as3D(),
            top.as3D(z: height)
        )
    }
    public var boundary: Bounds { .empty } // Unused
}
