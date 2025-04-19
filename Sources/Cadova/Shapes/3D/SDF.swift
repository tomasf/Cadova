import Foundation
import Manifold3D

public struct LevelSet: CompositeGeometry {
    public typealias D = D3

    let function: @Sendable (Vector3D) -> Double
    let bounds: BoundingBox3D
    let edgeLength: Double
    let level: Double
    let tolerance: Double?
    let cacheKey: NamedCacheKey

    public init(
        bounds: BoundingBox3D,
        edgeLength: Double,
        level: Double = 0,
        tolerance: Double? = nil,
        name: String,
        cacheParameters: any Hashable & Sendable & Codable...,
        sdf: @Sendable @escaping (Vector3D) -> Double
    ) {
        self.function = sdf
        self.bounds = bounds
        self.edgeLength = edgeLength
        self.level = level
        self.tolerance = tolerance

        cacheKey = NamedCacheKey(operationName: name, parameters: cacheParameters)
    }

    public var body: D3.Geometry {
        CachingPrimitive(key: cacheKey, primitive: .levelSet(
            bounds: bounds.primitive,
            edgeLength: edgeLength,
            level: level,
            tolerance: tolerance ?? -1
        ){ function($0.vector3D) })
    }
}
