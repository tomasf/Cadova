import Foundation

private extension PartCatalog {
    func filtered(by semantic: PartSemantic?, matching requestedParts: [Part]?) -> [Part: [D3.BuildResult]] {
        var result = parts

        if let semantic {
            result = result.filter { $0.key.semantic == semantic }
        }

        if let requestedParts {
            result = result.filter { catalogPart, _ in
                requestedParts.contains { requestedPart in
                    if let requestedID = requestedPart.id {
                        return catalogPart.id == requestedID
                    } else {
                        return catalogPart.name == requestedPart.name && catalogPart.semantic == requestedPart.semantic
                    }
                }
            }
        }

        return result
    }

    func asGeometry(filteredBy semantic: PartSemantic? = nil, matching parts: [Part]? = nil) -> [Part: D3.Geometry] {
        filtered(by: semantic, matching: parts).mapValues { Union($0) }
    }
}

public extension Geometry {
    /// Reads the specified parts without detaching them, and provides them for further composition.
    ///
    /// This method scans the current geometry for the specified parts previously marked with `.inPart(_:)`.
    /// Unlike `detachingPart`, this does not remove any parts from the input geometry. Instead, all matching
    /// parts are collected and provided to the `reader` closure as a dictionary keyed by part.
    ///
    /// Use this when you want to inspect or reuse parts while keeping the original geometry intact — for example,
    /// to overlay, transform, or selectively include parts in additional structures.
    ///
    /// - Parameters:
    ///   - parts: The parts to read.
    ///   - reader: A closure that receives:
    ///       - base: The original geometry (unchanged).
    ///       - parts: A dictionary mapping parts to their combined geometries.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func readingParts<Output: Dimensionality>(
        matching parts: [Part],
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ base: D.Geometry, _ parts: [Part: D3.Geometry]) -> Output.Geometry
    ) -> Output.Geometry {
        readingResult(PartCatalog.self) { base, catalog in
            reader(base, catalog.asGeometry(matching: parts))
        }
    }

    /// Reads a single part without detaching it, and provides it for further composition.
    ///
    /// This method looks for a part previously marked with `.inPart(_:)`. Unlike `detachingPart`, it does not
    /// remove the part from the input geometry. If a matching part exists, its geometry is passed to the
    /// `reader` closure; otherwise, `nil` is passed.
    ///
    /// Use this to selectively inspect or reuse one specific part while keeping the base geometry intact — for
    /// example, to overlay annotations, apply transforms, or conditionally include the part in derived geometry.
    ///
    /// - Parameters:
    ///   - part: The part to read.
    ///   - reader: A closure that receives:
    ///       - base: The original geometry (unchanged).
    ///       - part: The combined geometry of the part, or `nil` if the part is not present.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func readingPart<Output: Dimensionality>(
        _ part: Part,
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ base: D.Geometry, _ part: D3.Geometry?) -> Output.Geometry
    ) -> Output.Geometry {
        readingResult(PartCatalog.self) { base, catalog in
            reader(base, catalog.asGeometry(matching: [part]).values.first)
        }
    }

    /// Reads parts of a given semantic without detaching them, and provides them for further composition.
    ///
    /// This method scans the current geometry for parts previously marked with `.inPart(named:type:)` that match
    /// the specified semantic (e.g. `.solid`, `.visual`, `.context`). Unlike `detachingPart`, this does not remove
    /// any parts from the input geometry. Instead, all matching parts are collected and provided to the `reader`
    /// closure as a dictionary keyed by part name.
    ///
    /// Use this when you want to inspect or reuse parts while keeping the original geometry intact — for example,
    /// to overlay, transform, or selectively include parts in additional structures.
    ///
    /// - Parameters:
    ///   - type: The semantic type of parts to read. Defaults to `.solid`.
    ///   - reader: A closure that receives:
    ///       - base: The original geometry (unchanged).
    ///       - parts: A dictionary mapping part names to their combined geometries for the given semantic.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func readingParts<Output: Dimensionality>(
        ofType type: PartSemantic = .solid,
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ base: D.Geometry, _ parts: [String: D3.Geometry]) -> Output.Geometry
    ) -> Output.Geometry {
        readingResult(PartCatalog.self) { base, catalog in
            let parts = catalog.asGeometry(filteredBy: type)
            let namedParts = Dictionary(uniqueKeysWithValues: parts.map { ($0.key.name, $0.value) })
            reader(base, namedParts)
        }
    }

    /// Reads a single named part of a given semantic without detaching it, and provides it for further composition.
    ///
    /// This method looks for a part previously marked with `.inPart(named:type:)` that matches both the provided
    /// `type` and `name`. Unlike `detachingPart`, it does not remove the part from the input geometry. If a
    /// matching part exists, its geometry is passed to the `reader` closure; otherwise, `nil` is passed.
    ///
    /// Use this to selectively inspect or reuse one specific part while keeping the base geometry intact — for
    /// example, to overlay annotations, apply transforms, or conditionally include the part in derived geometry.
    ///
    /// - Parameters:
    ///   - type: The semantic type of the part to read. Defaults to `.solid`.
    ///   - name: The exact name of the part to read.
    ///   - reader: A closure that receives:
    ///       - base: The original geometry (unchanged).
    ///       - part: The combined geometry of the named part, or `nil` if the part is not present.
    ///     The closure should return new geometry to be built.
    /// - Returns: A geometry object resulting from the `reader` closure.
    ///
    func readingPart<Output: Dimensionality>(
        ofType type: PartSemantic = .solid,
        named name: String,
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ base: D.Geometry, _ part: D3.Geometry?) -> Output.Geometry
    ) -> Output.Geometry {
        readingResult(PartCatalog.self) { base, catalog in
            reader(base, catalog.asGeometry(matching: [.named(name, semantic: type)]).values.first)
        }
    }
}
