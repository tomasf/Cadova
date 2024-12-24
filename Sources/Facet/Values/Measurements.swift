import Foundation
import Manifold

/// Represents a collection of measurements for a geometric structure.
///
/// This type encapsulates various metrics like bounding boxes, areas, and vertex counts,
/// tailored to either 2D or 3D geometries based on the specified dimensionality.
public struct Measurements<D: Dimensionality> {
    internal let primitive: D.Primitive
}

public extension Measurements2D {
    /// The bounding box of the 2D geometry.
    var boundingBox: BoundingBox2D? { .init(primitive.bounds) }

    /// The total area of the 2D geometry.
    var area: Double { primitive.area }

    /// The total number of vertices in the geometry.
    var pointCount: Int { primitive.vertexCount }

    /// The number of contours (closed paths) in the geometry.
    var contourCount: Int { primitive.contourCount }
}

public extension Measurements3D {
    /// The bounding box of the 3D geometry.
    var boundingBox: BoundingBox3D? { .init(primitive.bounds) }

    /// The total surface area of the 3D geometry.
    var surfaceArea: Double { primitive.surfaceArea }

    /// The total volume enclosed by the 3D geometry.
    var volume: Double { primitive.volume }

    /// The total number of vertices in the geometry.
    var pointCount: Int { primitive.vertexCount }

    /// The total number of edges in the geometry.
    var edgeCount: Int { primitive.edgeCount }

    /// The number of triangular faces in the geometry.
    var triangleCount: Int { primitive.triangleCount }
}

public typealias Measurements2D = Measurements<Dimensionality2>
public typealias Measurements3D = Measurements<Dimensionality3>
