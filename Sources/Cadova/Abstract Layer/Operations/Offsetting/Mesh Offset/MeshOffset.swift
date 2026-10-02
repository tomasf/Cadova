import Foundation

/// Offsets a closed triangle mesh: the surface at a given signed distance from it, found by dual contouring the
/// exact signed distance on an adaptive octree.
///
/// - The octree only covers the band around the offset surface: the distance changes no faster than position, so a
///   node whose center is farther from the offset than its half-diagonal can't contain it.
/// - A node may stay large when every face that could be nearest to any offset point inside it lies in one plane,
///   because the offset there is provably that plane. Everything else is refined to the base cell size, and further
///   where the fit is poor, down to a quarter of it.
/// - Where the offset function changes sign along a cell edge, the exact crossing and the distance gradient there
///   give a plane; each cell places one vertex by fitting its planes, which keeps flat faces flat and sharp creases
///   sharp. Edges and vertices are taken on the finest cells around them (Ju et al., minimal edges).
/// - Cells are then merged bottom up where one vertex fits within the tolerance and merging can't change the
///   topology, and the result is repaired and cleaned until it's a 2-manifold.
internal final class MeshOffset: @unchecked Sendable {   // shared read-only by the concurrent loops
    typealias Face = (Int, Int, Int)

    let field: MeshDistanceField
    let amount: Double
    /// Corner pieces for sharp joins; nil for round
    let corners: OffsetCorners?
    /// For rounding both sides at once, the function to contour instead of the offset
    let rounding: RoundingField?
    /// How far beyond the amount the surface can reach (the miter limit for sharp joins)
    let reachFactor: Double
    let cellSize: Double
    let tolerance: Double
    /// For merging curved parts no coarser than circles of the same curvature; nil to merge within the tolerance
    let segmentation: Segmentation?

    /// Grid units per base cell: cells with poor fits can be split this far below the base size
    static let refinementLevels = 2
    let unitsPerCell = 1 << MeshOffset.refinementLevels
    /// The largest planar cell, in base cells
    static let coarsestPlanarCells = 64

    let unit: Double
    let origin: Vector3D
    var octree: OffsetOctree
    let coarsest: Int

    let gridValues = GridTable(capacity: 1 << 16, shards: 64)
    let knownValues: GridTable.Reader
    /// Crossings found so far, indexed by edge and length: an edge's crossing never changes, so refitting after splits
    /// only has to find the new ones
    var crossingStore: [Crossing] = []
    let crossingIndex = GridTable(capacity: 1 << 14, shards: 64)
    let knownCrossings: GridTable.Reader
    var fits: [PlaneFit] = []
    /// The minimal edges of the last fit, and which of them cross, for contouring the same tree without finding
    /// them again
    var fittedEdges: (edges: [Edge], crossing: [Int])? = nil
    var merges: [Int: (node: Int, child: Int, fit: PlaneFit)] = [:]

    convenience init(field: MeshDistanceField, amount: Double, style: LineJoinStyle = .round, miterLimit: Double = 5, cellSize: Double, tolerance: Double, segmentation: Segmentation? = nil) {
        // Miters reach up to the limit; square and bevel corners stay within about 1.5 times the amount
        let reachFactor: Double = switch style {
        case .round: 1
        case .miter: max(miterLimit, 1.5)
        case .square, .bevel: 1.5
        }
        let corners = style == .round ? nil : OffsetCorners(field: field, amount: amount, style: style, miterLimit: miterLimit, tolerance: tolerance)
        self.init(field: field, amount: amount, reachFactor: reachFactor, corners: corners, rounding: nil, cellSize: cellSize, tolerance: tolerance, segmentation: segmentation)
    }

    /// Contours a shape rounded on both sides, which lies within the rounding's dilated mesh
    convenience init(rounding: RoundingField, dilated: MeshDistanceField, cellSize: Double, tolerance: Double, segmentation: Segmentation? = nil) {
        self.init(field: dilated, amount: 0, reachFactor: 1, corners: nil, rounding: rounding, cellSize: cellSize, tolerance: tolerance, segmentation: segmentation)
    }

    init(field: MeshDistanceField, amount: Double, reachFactor: Double, corners: OffsetCorners?, rounding: RoundingField?, cellSize: Double, tolerance: Double, segmentation: Segmentation?) {
        self.field = field
        self.amount = amount
        self.tolerance = tolerance
        self.segmentation = segmentation
        self.reachFactor = reachFactor
        self.corners = corners
        self.rounding = rounding
        knownValues = gridValues.reader
        knownCrossings = crossingIndex.reader

        var lower = field.vertices.first ?? .zero, upper = lower
        for v in field.vertices { lower = .min(lower, v); upper = .max(upper, v) }
        let modelExtent = max(upper.x - lower.x, upper.y - lower.y, upper.z - lower.z) + 2 * max(0, amount) * reachFactor
        // Keys hold 19 bits per axis; cells grow on models too large for that at this resolution
        var cellSize = cellSize
        while (modelExtent / cellSize + 4) * Double(1 << MeshOffset.refinementLevels) > Double(MeshOffset.maximumExtent) / 2 { cellSize *= 2 }
        self.cellSize = cellSize
        unit = cellSize / Double(1 << MeshOffset.refinementLevels)

        let margin = max(0, amount) * reachFactor + 2 * cellSize
        lower = lower - margin
        upper = upper + margin
        origin = lower
        let size = upper - lower
        let extent = max(size.x, size.y, size.z)
        let depth = max(1, Int(ceil(log2(extent / cellSize))))
        octree = OffsetOctree(extent: (1 << depth) << MeshOffset.refinementLevels)
        coarsest = MeshOffset.coarsestPlanarCells << MeshOffset.refinementLevels
    }

    func run() -> (vertices: [Vector3D], faces: [Face]) {
        buildTree()
        // Balancing only depends on the tree, so it comes before the first fit; refinement rebalances what it splits
        balance()
        computeFits()
        refine()
        simplify()
        return Self.cleanedUp(contourWithRepair())
    }
}
