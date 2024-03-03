import Foundation

fileprivate extension Environment.Facets {
    var specialVariables: [String: any SCADValue] {
        switch self {
        case .fixed (let count):
            ["$fn": count]
        case .dynamic (let minAngle, let minSize):
            ["$fa": minAngle, "$fs": minSize, "$fn": 0]
        }
    }
}

public extension Geometry3D {
    func usingFacets(_ facets: Environment.Facets) -> any Geometry3D {
        SetVariables3D(variables: facets.specialVariables, environment: { $0.withFacets(facets) }, body: self)
    }

    /// Set an adaptive facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fa` and `$fs` in OpenSCAD.
    /// - Parameters:
    ///   - minAngle: The minimum angle of each facet
    ///   - minSize: The minimum size of each facet

    func usingFacets(minAngle: Angle, minSize: Double) -> any Geometry3D {
        usingFacets(.dynamic(minAngle: minAngle, minSize: minSize))
    }

    /// Set a fixed facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fn` OpenSCAD.
    /// - Parameters:
    ///   - count: The number of facets to use per revolution.

    func usingFacets(count: Int) -> any Geometry3D {
        usingFacets(.fixed(count))
    }

    /// Set the default facet configuration for this geometry.

    func usingDefaultFacets() -> any Geometry3D {
        usingFacets(.defaults)
    }
}

public extension Geometry2D {
    internal func usingFacets(_ facets: Environment.Facets) -> any Geometry2D {
        SetVariables2D(variables: facets.specialVariables, environment: { $0.withFacets(facets) }, body: self)
    }

    /// Set an adaptive facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fa` and `$fs` in OpenSCAD.
    /// - Parameters:
    ///   - minAngle: The minimum angle of each facet
    ///   - minSize: The minimum size of each facet

    func usingFacets(minAngle: Angle, minSize: Double) -> any Geometry2D {
        usingFacets(.dynamic(minAngle: minAngle, minSize: minSize))
    }

    /// Set a fixed facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fn` OpenSCAD.
    /// - Parameters:
    ///   - count: The number of facets to use per revolution.

    func usingFacets(count: Int) -> any Geometry2D {
        usingFacets(.fixed(count))
    }

    /// Set the default facet configuration for this geometry.

    func usingDefaultFacets() -> any Geometry2D {
        usingFacets(.defaults)
    }
}
