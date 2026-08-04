import Foundation

public extension GeometryEvaluator {
    /// Returns all parts of `geometry` whose semantic matches `type`, keyed by ``Part``.
    ///
    /// The original geometry is not modified — parts are read in place. This is the evaluator
    /// equivalent of ``Geometry/readingParts(ofType:reader:)``. Use it to inspect or selectively
    /// reuse parts of a model (for example, to overlay all `.visual` parts or to lay out each
    /// `.solid` part for inspection) without detaching them.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to inspect.
    ///   - type: The semantic of parts to read. Defaults to `.solid`.
    /// - Returns: A dictionary mapping each matching part to its combined geometry.
    ///
    func parts<D: Dimensionality>(of geometry: D.Geometry, ofType type: PartSemantic = .solid) async -> [Part: D3.Geometry] {
        await capture(fallback: [:]) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[PartCatalog.self].asGeometry(filteredBy: type)
        }
    }

    /// Returns the geometry of a single named part of `geometry`, or `nil` if the part is not present.
    ///
    /// The original geometry is not modified. This is the evaluator equivalent of
    /// ``Geometry/readingPart(_:reader:)``.
    ///
    /// - Parameters:
    ///   - part: The part to read.
    ///   - geometry: The geometry to inspect.
    /// - Returns: The combined geometry of the named part, or `nil` if it is not present.
    ///
    func part<D: Dimensionality>(_ part: Part, of geometry: D.Geometry) async -> D3.Geometry? {
        await capture(fallback: nil) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[PartCatalog.self].asGeometry(matching: [part]).values.first
        }
    }
}
