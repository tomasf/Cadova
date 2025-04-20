import Foundation
import Manifold3D

public extension Geometry {
    internal func usingFacets(_ facets: EnvironmentValues.Facets) -> D.Geometry {
        withEnvironment { $0.withFacets(facets) }
    }

    /// Set an adaptive facet configuration for this geometry
    ///
    /// - Parameters:
    ///   - minAngle: The minimum angle of each facet
    ///   - minSize: The minimum size of each facet

    func usingFacets(minAngle: Angle, minSize: Double) -> D.Geometry {
        usingFacets(.dynamic(minAngle: minAngle, minSize: minSize))
    }

    /// Set a fixed facet configuration for this geometry
    ///
    /// - Parameters:
    ///   - count: The number of facets to use per revolution.

    func usingFacets(count: Int) -> D.Geometry {
        usingFacets(.fixed(count))
    }

    /// Set the default facet configuration for this geometry.

    func usingDefaultFacets() -> D.Geometry {
        usingFacets(.defaults)
    }

    internal func declaringFacets() -> D.Geometry {
        readEnvironment(\.facets) { usingFacets($0) }
    }
}
