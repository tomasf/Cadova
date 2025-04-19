import Foundation
import Manifold3D

/// Represents a collection of measurements for a geometric structure.
///
/// This type encapsulates various metrics like bounding boxes, areas, and vertex counts,
/// tailored to either 2D or 3D geometries based on the specified dimensionality.
public struct Measurements<D: Dimensionality>: Sendable {
    internal let primitive: D.Primitive
}

public extension Measurements {
    /// The bounding box of the geometry.
    var boundingBox: BoundingBox<D>? {
        isEmpty ? nil : .init(primitive.bounds)
    }

    /// Is this geometry empty?
    var isEmpty: Bool { .init(primitive.isEmpty) }
}

public extension Measurements2D {
    /// The total area of the 2D geometry.
    var area: Double { primitive.area }

    /// The total number of vertices in the geometry.
    var pointCount: Int { primitive.vertexCount }

    /// The number of contours (closed paths) in the geometry.
    var contourCount: Int { primitive.contourCount }
}

public extension Measurements3D {
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

extension Measurements: CustomDebugStringConvertible {
    public var debugDescription: String {
        let items: [String: Any]

        if let self = self as? Measurements2D {
            items = [
                "Bounding box": boundingBox ?? "none",
                "Is empty": isEmpty,
                "Area": self.area,
                "Point count": self.pointCount,
                "Contour count": self.contourCount
            ]
        } else if let self = self as? Measurements3D {
            items = [
                "Bounding box": boundingBox ?? "none",
                "Is empty": isEmpty,
                "Surface area": self.surfaceArea,
                "Volume": self.volume,
                "Point count": self.pointCount,
                "Edge count": self.edgeCount,
                "Triangle count": self.triangleCount
            ]
        } else { return "" }

        return items
            .sorted(by: { $0.key < $1.key })
            .map { $0 + ": " + String(describing: $1) }
            .joined(separator: "\n")
    }
}

public typealias Measurements2D = Measurements<D2>
public typealias Measurements3D = Measurements<D3>
