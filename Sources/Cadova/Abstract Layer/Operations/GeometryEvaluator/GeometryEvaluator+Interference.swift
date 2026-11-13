import Foundation

/// An overlap between two bodies, found by ``GeometryEvaluator/interferences(among:including:ignoring:minimumVolume:)``.
///
/// `Body` identifies the two bodies: a ``Part`` when checking the parts of an assembly, or whatever key you used
/// when checking a dictionary of geometries.
///
public struct Interference<Body: Hashable & Sendable>: Sendable {
    /// The first of the two overlapping bodies.
    public let first: Body

    /// The second of the two overlapping bodies.
    public let second: Body

    /// The volume of the overlap, in cubic millimeters (mm³).
    public let volume: Double

    /// The overlapping region itself: the intersection of the two bodies.
    public let geometry: any Geometry3D
}

public extension GeometryEvaluator {
    /// Finds the parts of an assembly that overlap each other.
    ///
    /// Every pair of parts in `geometry` whose semantic is in `semantics` is checked, and each pair that overlaps
    /// by at least `minimumVolume` is returned, largest overlap first. Pairs whose bounding boxes don't meet are
    /// skipped without intersecting them, and the remaining pairs are checked in parallel. The main geometry, which
    /// isn't in any part, is not included; place it in a part of its own to check it too.
    ///
    /// ```swift
    /// let overlaps = await evaluator.interferences(
    ///     among: Assembly(),
    ///     ignoring: [(.oRings, .frontCap)]   // modelled uncompressed, so they overlap on purpose
    /// )
    /// #expect(overlaps.isEmpty)
    /// ```
    ///
    /// - Parameters:
    ///   - geometry: The assembly whose parts to check.
    ///   - semantics: The kinds of parts to check. Defaults to `.solid` and `.context`, which covers printed parts
    ///     and bought parts modelled for reference, and leaves out `.visual` parts such as guides and markers.
    ///   - ignoredPairs: Pairs of parts that are allowed to overlap, in either order.
    ///   - minimumVolume: The smallest overlap, in mm³, that counts. Parts that only touch, or overlap by less
    ///     than this from rounding, are not reported.
    /// - Returns: The overlapping pairs, largest overlap first.
    ///
    func interferences(
        among geometry: any Geometry3D,
        including semantics: Set<PartSemantic> = [.solid, .context],
        ignoring ignoredPairs: [(Part, Part)] = [],
        minimumVolume: Double = 0.01
    ) async -> [Interference<Part>] {
        let parts: [Part: any Geometry3D] = await capture(fallback: [:]) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[PartCatalog.self].asGeometry()
                .filter { semantics.contains($0.key.semantic) }
        }
        return await interferences(among: parts, ignoring: ignoredPairs, minimumVolume: minimumVolume)
    }

    /// Finds the geometries in a collection that overlap each other.
    ///
    /// Use this to check bodies that aren't parts of one assembly, such as separately built components placed in
    /// their assembled positions. Every pair is checked, and each pair that overlaps by at least `minimumVolume` is
    /// returned, largest overlap first. Only each geometry's main body is considered; parts inside it are not.
    ///
    /// ```swift
    /// let overlaps = await evaluator.interferences(among: [
    ///     "Shell": Shell(),
    ///     "Lid": Lid().seated,
    ///     "Coil": coil,
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - bodies: The geometries to check, keyed by whatever identifies them in the result.
    ///   - ignoredPairs: Pairs of keys that are allowed to overlap, in either order.
    ///   - minimumVolume: The smallest overlap, in mm³, that counts. Bodies that only touch, or overlap by less
    ///     than this from rounding, are not reported.
    /// - Returns: The overlapping pairs, largest overlap first.
    ///
    func interferences<Body: Hashable & Sendable>(
        among bodies: [Body: any Geometry3D],
        ignoring ignoredPairs: [(Body, Body)] = [],
        minimumVolume: Double = 0.01
    ) async -> [Interference<Body>] {
        await interferences(among: bodies, minimumVolume: minimumVolume) { a, b in
            ignoredPairs.contains { ($0.0 == a && $0.1 == b) || ($0.0 == b && $0.1 == a) }
        }
    }
}

internal extension GeometryEvaluator {
    func interferences<Body: Hashable & Sendable>(
        among bodies: [Body: any Geometry3D],
        minimumVolume: Double,
        isIgnored: (Body, Body) -> Bool
    ) async -> [Interference<Body>] {
        let entries = Array(bodies)

        let boxes = await withTaskGroup(of: (Int, BoundingBox3D?).self) { group in
            for (index, entry) in entries.enumerated() {
                group.addTask { (index, await self.bounds(of: entry.value, scope: .mainPart)) }
            }
            var boxes = [BoundingBox3D?](repeating: nil, count: entries.count)
            for await (index, box) in group {
                boxes[index] = box
            }
            return boxes
        }

        var candidates: [(Int, Int)] = []
        for i in entries.indices {
            for j in entries.indices where j > i {
                guard let a = boxes[i], let b = boxes[j], a.intersection(with: b) != nil,
                      !isIgnored(entries[i].key, entries[j].key)
                else { continue }
                candidates.append((i, j))
            }
        }

        let interferences = await withTaskGroup(of: Interference<Body>?.self) { group in
            for (i, j) in candidates {
                let first = entries[i]
                let second = entries[j]
                group.addTask {
                    let overlap = first.value.intersecting(second.value)
                    let volume = await self.measurements(of: overlap, scope: .mainPart).volume
                    guard volume >= minimumVolume else { return nil }
                    return Interference(first: first.key, second: second.key, volume: volume, geometry: overlap)
                }
            }
            var found: [Interference<Body>] = []
            for await interference in group {
                if let interference { found.append(interference) }
            }
            return found
        }

        return interferences.sorted { $0.volume > $1.volume }
    }
}
