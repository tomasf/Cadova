import Foundation
import Manifold3D

public extension Measurements2D {
    /// The area-weighted center of the 2D geometry, or `nil` if the geometry is empty.
    var centroid: Vector2D? {
        let weighted = concrete
            .map(\.areaCentroidAndArea)
            .filter { $0.area > 0 }

        let totalArea = weighted.sum(\.area)
        guard totalArea > 0 else { return nil }

        return weighted
            .map { $0.centroid * $0.area }
            .reduce(.zero, +) / totalArea
    }
}

public extension Measurements3D {
    /// The volume-weighted center of the 3D geometry, or `nil` if the geometry is empty.
    var centroid: Vector3D? {
        let weighted = concrete
            .map(\.volumeCentroidAndVolume)
            .filter { $0.volume > 0 }

        let totalVolume = weighted.sum(\.volume)
        guard totalVolume > 0 else { return nil }

        return weighted
            .map { $0.centroid * $0.volume }
            .reduce(.zero, +) / totalVolume
    }
}

private extension CrossSection {
    var areaCentroidAndArea: (centroid: Vector2D, area: Double) {
        let polygons = polygonList()
        var weightedCentroid = Vector2D.zero
        var totalArea = 0.0

        for (aRef, bRef, cRef) in polygons.triangulated() {
            let a = polygons[aRef]
            let b = polygons[bRef]
            let c = polygons[cRef]
            let signedDoubleArea = (b - a) × (c - a)
            let triangleArea = abs(signedDoubleArea) / 2.0
            guard triangleArea > 0 else { continue }

            weightedCentroid += (a + b + c) / 3.0 * triangleArea
            totalArea += triangleArea
        }

        guard totalArea > 0 else { return (.zero, 0) }
        return (weightedCentroid / totalArea, totalArea)
    }
}

private extension Manifold {
    var volumeCentroidAndVolume: (centroid: Vector3D, volume: Double) {
        let mesh = meshGL()
        let vertices = mesh.vertices
        var weightedCentroid = Vector3D.zero
        var signedVolume = 0.0

        for triangle in mesh.triangles {
            let a = vertices[triangle.a]
            let b = vertices[triangle.b]
            let c = vertices[triangle.c]
            let tetrahedronVolume = (a ⋅ (b × c)) / 6.0
            guard tetrahedronVolume != 0 else { continue }

            weightedCentroid += (a + b + c) / 4.0 * tetrahedronVolume
            signedVolume += tetrahedronVolume
        }

        guard signedVolume != 0 else { return (.zero, 0) }
        return (weightedCentroid / signedVolume, abs(signedVolume))
    }
}
