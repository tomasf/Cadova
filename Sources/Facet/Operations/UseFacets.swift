import Foundation

fileprivate extension EnvironmentValues.Facets {
    var specialVariables: CodeFragment.Parameters {
        switch self {
        case .fixed (let count):
            ["$fn": count]
        case .dynamic (let minAngle, let minSize):
            ["$fa": minAngle, "$fs": minSize, "$fn": 0]
        }
    }
}

public extension Geometry2D {
    internal func usingFacets(_ facets: EnvironmentValues.Facets) -> any Geometry2D {
        SetVariables(body: self, variables: facets.specialVariables)
            .withEnvironment { $0.withFacets(facets) }
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

    internal func declaringFacets() -> any Geometry2D {
        readEnvironment(\.facets) { usingFacets($0) }
    }
}

public extension Geometry3D {
    func usingFacets(_ facets: EnvironmentValues.Facets) -> any Geometry3D {
        SetVariables(body: self, variables: facets.specialVariables)
            .withEnvironment { $0.withFacets(facets) }
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

    internal func declaringFacets() -> any Geometry3D {
        readEnvironment(\.facets) { usingFacets($0) }
    }
}
