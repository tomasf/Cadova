import Foundation
import Manifold3D

/// Represents a collection of measurements for a geometric structure.
///
/// This type encapsulates various metrics like bounding boxes, areas, and vertex counts,
/// tailored to either 2D or 3D geometries based on the specified dimensionality.
///
public struct Measurements<D: Dimensionality>: Sendable {
    internal let concrete: [D.Concrete]

    init(buildResult: D.BuildResult, scope: MeasurementScope, context: EvaluationContext) async throws {
        self.concrete = try await scope.includedConcretes(for: buildResult, in: context)
    }
}

public extension Measurements {
    /// The bounding box of the geometry.
    ///

    var boundingBox: BoundingBox<D>? {
        let boxes = concrete.compactMap { $0.isEmpty ? nil : BoundingBox<D>($0.bounds) }
        return boxes.isEmpty ? nil : BoundingBox(union: boxes)
    }

    /// The total number of vertices in the geometry.
    var pointCount: Int {
        concrete.sum(\.vertexCount)
    }

    /// The number of parts included in this measurement.
    ///
    /// This count reflects how many distinct concrete bodies were considered.
    /// It includes the main geometry and, when the scope allows it, other parts.
    ///
    var partCount: Int { concrete.count }

    /// Is this geometry empty?
    var isEmpty: Bool { .init(concrete.allSatisfy(\.isEmpty)) }
}

public extension Measurements2D {
    /// The total area of the 2D geometry.
    var area: Double { concrete.sum(\.area) }

    /// The number of contours (closed paths) in the geometry.
    var contourCount: Int { concrete.sum(\.contourCount) }

    /// Indicates whether the geometry consists of a single convex shape.
    var isConvex: Bool {
        let polygons = SimplePolygonList(concrete.map { $0.polygonList() })
        return polygons.count == 1 && polygons[0].isConvex
    }
}

public extension Measurements3D {
    /// The total surface area of the 3D geometry.
    var surfaceArea: Double { concrete.sum(\.surfaceArea) }

    /// The total volume enclosed by the 3D geometry.
    var volume: Double { concrete.sum(\.volume) }

    /// The total number of edges in the geometry.
    var edgeCount: Int { concrete.sum(\.edgeCount) }

    /// The number of triangular faces in the geometry.
    var triangleCount: Int { concrete.sum(\.triangleCount) }
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
                "Contour count": self.contourCount,
                "Is convex": self.isConvex
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

/// Controls which parts are included when computing ``Measurements``.
///
/// Use this to decide whether measurements (bounding boxes, counts, areas/volumes, etc.)
/// include only the main geometry, just the printable (solid) parts, or all parts.
///
public enum MeasurementScope: Hashable, Sendable {
    /// Measure only the main geometry.
    case mainPart

    /// Measure the main geometry plus all solid (printable) parts.
    case solidParts

    /// Measure the main geometry plus all parts, including `.solid`, `.context`, and `.visual`.
    case allParts
}
