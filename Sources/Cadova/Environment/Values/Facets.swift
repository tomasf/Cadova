import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.Facets")

    /// An enumeration representing the method for calculating the number of facets (or segments) used in rendering circular geometries.
    enum Facets: Sendable {
        /// Specifies a fixed number of facets for all circles, regardless of size.
        case fixed (Int)

        /// Specifies a dynamic calculation of facets based on the minimum angle and minimum size.
        /// - Parameters:
        ///   - minAngle: The minimum angle (in degrees) between facets.
        ///   - minSize: The minimum size of a facet.
        case dynamic (minAngle: Angle, minSize: Double)

        /// The default facet settings for Facet, aiming for higher detail in rendered geometries.
        public static let defaults = Facets.dynamic(minAngle: 2°, minSize: 0.15)

        /// Calculates the number of facets for a circle based on its radius and the current facet settings.
        ///
        /// For `dynamic`, it calculates the appropriate number of facets based on the minimum angle and size.
        /// - Parameter r: The radius of the circle.
        /// - Returns: The calculated number of facets for a full circle.
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

        /// Calculates the number of facets for an item based on its length and the current facet settings.
        ///
        /// For `dynamic`, it calculates the appropriate number of facets based on the minimum size
        /// - Parameter length: The total length
        /// - Returns: The calculated number of facets
        public func facetCount(length: Double) -> Int {
            switch self {
            case .fixed (let count):
                return max(count, 3)

            case .dynamic(_, let minSize):
                return Int(ceil(min(length / minSize, 5)))
            }
        }
    }

    /// Accesses the current facets setting from the environment.
    var facets: Facets {
        self[Self.environmentKey] as? Facets ?? .defaults
    }

    /// Returns a new environment with the specified facets settings applied.
    ///
    /// This method allows for precise control over the resolution of circular geometries.
    /// - Parameter facets: The `Facets` setting to apply to the environment.
    /// - Returns: A new `EnvironmentValues` with the updated facets settings.
    func withFacets(_ facets: Facets) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: facets)
    }
}
