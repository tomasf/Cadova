import Foundation

public extension Environment {
    enum Facets {
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

        static internal var environmentKey: Environment.ValueKey = .init(rawValue: "SwiftSCAD.Facets")
    }

    var facets: Facets {
        self[Facets.environmentKey] as? Facets ?? .defaults
    }

    func withFacets(_ facets: Facets) -> Environment {
        setting(key: Facets.environmentKey, value: facets)
    }
}

fileprivate extension Environment.Facets {
    func modification(body: Geometry, environment: Environment) -> String {
        let variables: [String: SCADValue]

        switch self {
        case .fixed (let count):
            variables = ["$fn": count]
        case .dynamic (let minAngle, let minSize):
            variables = ["$fa": minAngle, "$fs": minSize, "$fn": 0]
        }

        let newEnvironment = environment.withFacets(self)
        return SCADCall(name: "let", params: variables, body: body)
            .scadString(in: newEnvironment)
    }
}

struct SetFacets3D: Geometry3D {
    let facets: Environment.Facets
    let body: Geometry3D

    func scadString(in environment: Environment) -> String {
        facets.modification(body: body, environment: environment)
    }
}

struct SetFacets2D: Geometry2D {
    let facets: Environment.Facets
    let body: Geometry2D

    func scadString(in environment: Environment) -> String {
        facets.modification(body: body, environment: environment)
    }
}

public extension Geometry3D {
    internal func usingFacets(_ facets: Environment.Facets) -> Geometry3D {
        SetFacets3D(facets: facets, body: withEnvironment { environment in
            environment.setting(key: Environment.Facets.environmentKey, value: facets)
        })
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

public extension Geometry2D {
    internal func usingFacets(_ facets: Environment.Facets) -> Geometry2D {
        SetFacets2D(facets: facets, body: withEnvironment { environment in
            environment.setting(key: Environment.Facets.environmentKey, value: facets)
        })
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
