import Foundation

private func facetModification(_ facets: Environment.Facets, body: Geometry, environment: Environment) -> String {
    let variables: [String: SCADValue]

    switch facets {
    case .fixed (let count):
        variables = ["$fn": count]
    case .dynamic (let minAngle, let minSize):
        variables = ["$fa": minAngle, "$fs": minSize, "$fn": 0]
    }

    let newEnvironment = environment.withFacets(facets)

    return SCADCall(name: "let", params: variables, body: body)
        .scadString(in: newEnvironment)
}


struct SetFacets3D: Geometry3D {
    let facets: Environment.Facets
    let body: Geometry3D

    func scadString(in environment: Environment) -> String {
        facetModification(facets, body: body, environment: environment)
    }
}

public extension Geometry3D {
    internal func usingFacets(_ facets: Environment.Facets) -> Geometry3D {
        SetFacets3D(facets: facets, body: self)
    }

    /// Set an adaptive facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fa` and `$fs` in OpenSCAD.
    /// - Parameters:
    ///   - minAngle: The minimum angle of each facet
    ///   - minSize: The minimum size of each facet

    func usingFacets(minAngle: Angle, minSize: Double) -> Geometry3D {
        usingFacets(.dynamic(minAngle: minAngle, minSize: minSize))
    }

    /// Set a fixed facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fn` OpenSCAD.
    /// - Parameters:
    ///   - count: The number of facets to use per revolution.

    func usingFacets(count: Int) -> Geometry3D {
        usingFacets(.fixed(count))
    }

    /// Set the default facet configuration for this geometry.

    func usingDefaultFacets() -> Geometry3D {
        usingFacets(.defaults)
    }
}


struct SetFacets2D: Geometry2D {
    let facets: Environment.Facets
    let body: Geometry2D

    func scadString(in environment: Environment) -> String {
        facetModification(facets, body: body, environment: environment)
    }
}

public extension Geometry2D {
    internal func usingFacets(_ facets: Environment.Facets) -> Geometry2D {
        SetFacets2D(facets: facets, body: self)
    }

    /// Set an adaptive facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fa` and `$fs` in OpenSCAD.
    /// - Parameters:
    ///   - minAngle: The minimum angle of each facet
    ///   - minSize: The minimum size of each facet

    func usingFacets(minAngle: Angle, minSize: Double) -> Geometry2D {
        usingFacets(.dynamic(minAngle: minAngle, minSize: minSize))
    }

    /// Set a fixed facet configuration for this geometry
    ///
    /// This is equivalent to setting `$fn` OpenSCAD.
    /// - Parameters:
    ///   - count: The number of facets to use per revolution.

    func usingFacets(count: Int) -> Geometry2D {
        usingFacets(.fixed(count))
    }

    /// Set the default facet configuration for this geometry.

    func usingDefaultFacets() -> Geometry2D {
        usingFacets(.defaults)
    }
}
