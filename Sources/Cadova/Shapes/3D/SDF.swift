import Foundation
import Manifold3D

public struct LevelSet: LeafGeometry, Geometry3D {
    typealias D = D3

    let function: (Vector3D) -> Double
    let bounds: BoundingBox3D
    let edgeLength: Double
    let level: Double
    let tolerance: Double?

    public init(sdf: @escaping (Vector3D) -> Double, bounds: BoundingBox3D, edgeLength: Double, level: Double = 0, tolerance: Double? = nil) {
        self.function = sdf
        self.bounds = bounds
        self.edgeLength = edgeLength
        self.level = level
        self.tolerance = tolerance
    }

    var body: D3.Primitive {
        .levelSet(bounds: bounds.primitive, edgeLength: edgeLength, level: level, tolerance: tolerance ?? -1) { function($0.vector3D) }
    }
}
