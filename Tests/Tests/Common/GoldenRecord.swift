import Foundation
@testable import Cadova

/// A simplified key for golden record comparison that ignores Part's UUID
private struct PartKey: Hashable, Codable {
    let name: String
    let semantic: PartSemantic

    init(_ part: Part) {
        self.name = part.name
        self.semantic = part.semantic
    }
}

struct GoldenRecord<D: Dimensionality>: Sendable, Hashable, Codable {
    private let parts: [PartKey: D.Node]
    private let measurements: [PartKey: RealizedMeasurements]

    init(result: _BuildResult<D>, context: _EvaluationContext) async throws {
        let parts: [PartKey: D.Node]

        if let result2D = result as? _BuildResult<D2> {
            parts = [PartKey(.main): result2D.node as! D.Node]
        } else if let result3D = result as? _BuildResult<D3> {
            var all: [PartKey: D.Node] = result.elements[PartCatalog.self].mergedOutputs
                .reduce(into: [:]) { $0[PartKey($1.key)] = $1.value.node as? D.Node }
            all[PartKey(.main)] = (result3D.node as! D.Node)
            parts = all
        } else {
            fatalError("Invalid geometry type")
        }

        self.parts = parts

        var measurements: [PartKey: RealizedMeasurements] = [:]
        for (key, node) in parts {
            measurements[key] = try await RealizedMeasurements(
                buildResult: result.replacing(node: node), context: context
            )
        }
        self.measurements = measurements
    }

    init(url: URL) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    var jsonString: String {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            return String(decoding: try encoder.encode(self), as: UTF8.self)
        }
    }

    func write(to url: URL) throws {
        try Data(jsonString.utf8).write(to: url)
    }
}

extension GoldenRecord: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        parts.equals(other.parts, within: tolerance)
        && measurements.equals(other.measurements, within: tolerance)
    }
}

/// Invariants measured from the mesh the geometry kernel actually produced.
///
/// A node expression is a recipe, not geometry. Comparing only the expression leaves the entire
/// realization step unguarded: a golden that records nothing else still passes if Manifold's boolean
/// starts returning nonsense. Recording these alongside the expression puts the realized result under
/// assertion too.
///
/// Only quantities that survive the kernel's non-determinism belong here, and rather less survives it
/// than one would hope. `GeometryNode.boolean` sorts a union's children by `hash`, which Swift seeds
/// per process, so the operands reach Manifold in a different order on every run. Two things follow,
/// both measured rather than assumed:
///
/// - The triangulation is not reproducible. Across five separate processes the six-sided edge-profile
///   model in `3d/edge-profile-side-orientation` realized 444, 444, 454, 438 and 458 triangles
///   (231–241 vertices). Triangle and vertex counts are therefore absent, tempting as they look.
///
/// - Neither is surface area, wherever a union has to resolve coincident internal faces. The angled
///   split in `splitAlongPlane` unions two halves that share the cut face, and measures 706.417777 mm²
///   in some processes and 705.266070 mm² in others — 0.16% apart, and constant across 40 evaluations
///   *within* a process, which is what pins the cause on operand order rather than thread scheduling.
///   No principled tolerance covers that: the discrepancy is a fraction of a whole shared face, so it
///   scales with the model, not with floating-point error. Surface area is therefore absent too.
///
/// Volume, bounding box and centroid came out identical under both operand orders — a watertight
/// boolean encloses the same space however it got there — and those are what remain.
struct RealizedMeasurements: Sendable, Hashable, Codable {
    /// Measured values are compared relative to a scale, rather than to their own magnitude alone.
    ///
    /// Run-to-run drift within one machine is about 2e-15 relative. Across machines it is far larger,
    /// because the arithmetic itself differs: `3d/wrap` measures a volume of 11411.657893 on macOS and
    /// 11411.658549 on Linux, 5.7e-8 apart, with a centroid component moving by about 1e-6 while the
    /// bounding box stays identical to the last digit. A tolerance calibrated on one platform is not a
    /// tolerance, so this one is calibrated against all three.
    ///
    /// 1e-5 leaves two orders of magnitude over the largest cross-platform drift measured, and stays
    /// two orders tighter than any geometric change worth noticing: widening the edge-profile
    /// interface margin from 5e-3 to 1e-2, the subtlest real drift in this suite's history, moves
    /// volumes by parts in a thousand.
    static let relativeTolerance = 1e-5

    let isEmpty: Bool
    let boundingBox: MeasuredBoundingBox?
    let centroid: [Double]?

    /// mm², for 2D geometry only.
    let area: Double?

    /// mm³, for 3D geometry only.
    let volume: Double?

    init<D: Dimensionality>(buildResult: _BuildResult<D>, context: _EvaluationContext) async throws {
        let measurements = try await D.Measurements(buildResult: buildResult, scope: .mainPart, context: context)

        isEmpty = measurements.isEmpty
        boundingBox = measurements.boundingBox.map {
            MeasuredBoundingBox(minimum: Array($0.minimum), maximum: Array($0.maximum))
        }

        if let measurements = measurements as? Measurements2D {
            centroid = measurements.centroid.map { Array($0) }
            area = measurements.area
            volume = nil
        } else if let measurements = measurements as? Measurements3D {
            centroid = measurements.centroid.map { Array($0) }
            area = nil
            volume = measurements.volume
        } else {
            fatalError("Invalid geometry type")
        }
    }
}

struct MeasuredBoundingBox: Sendable, Hashable, Codable {
    let minimum: [Double]
    let maximum: [Double]
}

extension RealizedMeasurements: ApproximatelyEquatable {
    // The tolerance the ≈ operator hands down is an absolute one, sized for the coordinates in a node
    // expression. Measured quantities span millimeters to cubic millimeters of a whole model, so they
    // are compared against `relativeTolerance` instead. The incoming value is deliberately unnamed
    // here, so that a caller reading this conformance cannot mistake it for one that is honoured.
    func equals(_ other: Self, within _: Double) -> Bool {
        // A coordinate is compared against the model's own size rather than against its own value. A
        // centroid near the origin is a small number left over from cancelling large ones, so what
        // limits its accuracy is how big the model is, not how close to zero it landed.
        let scale = Swift.max(extent, other.extent)

        return isEmpty == other.isEmpty
        && matches(boundingBox?.minimum, other.boundingBox?.minimum, scale: scale)
        && matches(boundingBox?.maximum, other.boundingBox?.maximum, scale: scale)
        && matches(centroid, other.centroid, scale: scale)
        && matches(area, other.area)
        && matches(volume, other.volume)
    }

    /// The model's longest side, or 1 for geometry with no bounding box to measure.
    private var extent: Double {
        guard let boundingBox else { return 1 }
        return Swift.max(1, zip(boundingBox.maximum, boundingBox.minimum).map(-).max() ?? 1)
    }
}

/// Compares two measured quantities relative to their own magnitude, with an absolute floor of the
/// same size so a quantity legitimately near zero doesn't demand impossible precision.
private func matches(_ mine: Double?, _ theirs: Double?, scale minimumScale: Double = 1) -> Bool {
    guard let mine, let theirs else { return mine == nil && theirs == nil }
    let scale = Swift.max(minimumScale, Swift.abs(mine), Swift.abs(theirs))
    return Swift.abs(mine - theirs) <= RealizedMeasurements.relativeTolerance * scale
}

private func matches(_ mine: [Double]?, _ theirs: [Double]?, scale minimumScale: Double = 1) -> Bool {
    guard let mine, let theirs else { return mine == nil && theirs == nil }
    return mine.count == theirs.count
        && zip(mine, theirs).allSatisfy { matches($0, $1, scale: minimumScale) }
}

private extension Part {
    static let main = Part("Model", semantic: .solid)
}
