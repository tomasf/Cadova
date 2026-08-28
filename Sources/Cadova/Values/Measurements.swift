import Foundation
import Manifold3D

/// Represents a collection of measurements for a geometric structure.
///
/// This type encapsulates various metrics like bounding boxes, areas, and vertex counts,
/// tailored to either 2D or 3D geometries based on the specified dimensionality.
///
public struct Measurements<D: Dimensionality>: Sendable {
    internal let parts: [MeasuredPart<D>]

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    init(buildResult: BuildResult<D>, scope: MeasurementScope, context: EvaluationContext) async throws {
        self.parts = try await scope.includedConcretes(for: buildResult, in: context)
    }

    internal init() {
        self.parts = []
    }

    internal var concrete: [D.Concrete] { parts.map(\.concrete) }
}

// A single measured body together with the node it came from and the cache that memoizes its
// expensive derived properties (volume, surface area, centroid, convexity). Keying the cache by
// node lets these survive across separate `Measurements` instances that measure the same geometry.
internal struct MeasuredPart<D: Dimensionality>: Sendable {
    let node: D.Node
    let concrete: D.Concrete
    let cache: GeometryCache<D>
}

// `centroidAndWeight`'s outer optional distinguishes "not yet computed" from a computed result;
// the weight itself may legitimately be zero (empty/degenerate geometry).
internal struct CachedMeasurements<D: Dimensionality>: Sendable {
    var volume: Double?
    var surfaceArea: Double?
    var area: Double?
    var centroidAndWeight: (centroid: D.Vector, weight: Double)?
    var isConvex: Bool?
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
    var isEmpty: Bool { concrete.allSatisfy(\.isEmpty) }
}

public extension Measurements2D {
    /// The total area of the 2D geometry, in square millimeters (mm²).
    var area: Double { parts.sum(\.area) }

    /// The number of contours (closed paths) in the geometry.
    var contourCount: Int { concrete.sum(\.contourCount) }

    /// Indicates whether the geometry consists of a single convex shape.
    var isConvex: Bool { parts.first?.isConvex ?? false }
}

public extension Measurements3D {
    /// The total surface area of the 3D geometry, in square millimeters (mm²).
    var surfaceArea: Double { parts.sum(\.surfaceArea) }

    /// The total volume enclosed by the 3D geometry, in cubic millimeters (mm³).
    var volume: Double { parts.sum(\.volume) }

    /// The total number of edges in the geometry.
    var edgeCount: Int { concrete.sum(\.edgeCount) }

    /// The number of triangular faces in the geometry.
    var triangleCount: Int { concrete.sum(\.triangleCount) }
}

internal extension MeasuredPart where D == D2 {
    // 2D measurement scopes always resolve to a single part (parts are a 3D-only concept), so
    // `isConvex` only ever needs to consider this one body.
    var isConvex: Bool {
        if let cached = cache.cachedMeasurements(for: node).isConvex { return cached }
        let polygons = SimplePolygonList([concrete.polygonList()])
        let value = polygons.count == 1 && polygons[0].isConvex
        cache.updateCachedMeasurements(for: node) { $0.isConvex = value }
        return value
    }

    // `centroidAndWeight`, when already cached, derived this same area as a byproduct: reuse it
    // instead of asking the underlying geometry to redo the work.
    var area: Double {
        let cached = cache.cachedMeasurements(for: node)
        if let value = cached.area { return value }
        if let value = cached.centroidAndWeight?.weight { return value }
        let value = concrete.area
        cache.updateCachedMeasurements(for: node) { $0.area = value }
        return value
    }
}

internal extension MeasuredPart where D == D3 {
    // `centroidAndWeight`, when already cached, derived this same volume as a byproduct: reuse it
    // instead of asking the underlying geometry to redo the work.
    var volume: Double {
        let cached = cache.cachedMeasurements(for: node)
        if let value = cached.volume { return value }
        if let value = cached.centroidAndWeight?.weight { return value }
        let value = concrete.volume
        cache.updateCachedMeasurements(for: node) { $0.volume = value }
        return value
    }

    var surfaceArea: Double {
        if let cached = cache.cachedMeasurements(for: node).surfaceArea { return cached }
        let value = concrete.surfaceArea
        cache.updateCachedMeasurements(for: node) { $0.surfaceArea = value }
        return value
    }
}

extension Measurements: CustomDebugStringConvertible {
    public var debugDescription: String {
        let items: [String: Any]

        if let self = self as? Measurements2D {
            items = [
                "Bounding box": boundingBox ?? "none",
                "Centroid": self.centroid ?? "none",
                "Is empty": isEmpty,
                "Area": self.area,
                "Point count": self.pointCount,
                "Contour count": self.contourCount,
                "Is convex": self.isConvex
            ]
        } else if let self = self as? Measurements3D {
            items = [
                "Bounding box": boundingBox ?? "none",
                "Centroid": self.centroid ?? "none",
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
