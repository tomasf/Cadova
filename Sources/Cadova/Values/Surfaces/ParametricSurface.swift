import Foundation

/// A curved surface in 3D space, described by a point for every pair of parameters `(u, v)` within its domain.
///
/// A surface is an open sheet, not a solid. Turn it into one with ``enclosed(against:)``, ``enclosed(to:)`` or
/// ``enclosed(offset:)``, or lay other geometry onto it with `draped(over:)`.
///
/// Cadova provides these surfaces:
/// - ``BezierPatch``, shaped by a grid of control points.
/// - ``SplineSurface``, a NURBS surface shaped by a grid of weighted control points, which can describe exact
///   sections of cylinders, spheres and other conic shapes.
/// - ``InterpolatingSurface``, passing through every point of a grid.
/// - ``RuledSurface``, made of straight lines between two curves.
/// - ``CoonsPatch``, filling the area bounded by four curves.
///
/// Like a curve's `domain`, ``uDomain`` and ``vDomain`` are the ranges of parameters a surface accepts. Each type uses
/// its natural range, such as `0...1` for a ``BezierPatch``. Use ``remapped(u:v:)`` to give a surface a different
/// one, for example to match its size.
///
/// You can conform your own types to describe other kinds of surfaces. The only requirement is
/// ``point(at:)``; the domain defaults to `0...1` in both directions, and the surface is tessellated by sampling it
/// according to the environment's segmentation.
///
public protocol ParametricSurface: Sendable, Hashable, Codable {
    /// The range of `u` values the surface accepts.
    var uDomain: ClosedRange<Double> { get }

    /// The range of `v` values the surface accepts.
    var vDomain: ClosedRange<Double> { get }

    /// Returns the point on the surface at the given parameters.
    ///
    /// The surfaces Cadova provides accept parameters outside their domain too, and continue past their edges
    /// along their tangent planes. Your own conformance only needs to handle parameters within the domain: Cadova
    /// calls it with no others, and extends the surface past its edges the same way.
    ///
    /// - Parameter uv: The surface parameters, `u` (`x`) and `v` (`y`).
    /// - Returns: The point on the surface.
    func point(at uv: Vector2D) -> Vector3D
}

public extension ParametricSurface {
    var uDomain: ClosedRange<Double> { 0...1 }
    var vDomain: ClosedRange<Double> { 0...1 }
}

internal extension ParametricSurface {
    /// The point at the given fractions of the way across the domain, each in `0...1`.
    func point(atFraction fraction: Vector2D) -> Vector3D {
        point(at: Vector2D(
            uDomain.lowerBound + uDomain.length * fraction.x,
            vDomain.lowerBound + vDomain.length * fraction.y
        ))
    }

    /// The point at the given parameters, with the surface continuing past its domain along its tangent planes.
    ///
    /// Within the domain, this is `evaluate(uv)`. Past an edge, every line across that edge carries on straight,
    /// along the surface's slope across the edge, the way a sweep carries on past the end of its curve. Past a
    /// corner, both slopes apply, so the surface carries on as the flat tangent plane at that corner. Either way it
    /// meets the surface without a gap or a crease. `evaluate` is only ever called within the domain.
    func point(at uv: Vector2D, extendingPast evaluate: (Vector2D) -> Vector3D) -> Vector3D {
        let edge = Vector2D(uv.x.clamped(to: uDomain), uv.y.clamped(to: vDomain))
        let edgePoint = evaluate(edge)
        let uBeyond = uv.x - edge.x, vBeyond = uv.y - edge.y
        guard uBeyond != 0 || vBeyond != 0 else { return edgePoint }

        // The slope across an edge, by a second-order difference stepping back into the domain. The step is small
        // enough to measure the slope at the edge itself, and large enough to stay well clear of rounding.
        func slope(across direction: Vector2D, domainLength: Double) -> Vector3D {
            guard domainLength > 0 else { return .zero }
            let step = domainLength * 1e-4
            let inside1 = evaluate(edge - direction * step)
            let inside2 = evaluate(edge - direction * (2 * step))
            return (edgePoint * 3 - inside1 * 4 + inside2) / (2 * step)
        }

        var point = edgePoint
        if uBeyond != 0 {
            point += slope(across: Vector2D(uBeyond > 0 ? 1 : -1, 0), domainLength: uDomain.length) * abs(uBeyond)
        }
        if vBeyond != 0 {
            point += slope(across: Vector2D(0, vBeyond > 0 ? 1 : -1), domainLength: vDomain.length) * abs(vBeyond)
        }
        return point
    }
}

/// A surface made of pieces, such as the rows of points an interpolating surface passes through, or the knot spans
/// of a spline surface. Adaptive segmentation probes each piece, so it can't miss what happens between two probes.
internal protocol ParametricSurfacePieces {
    /// The number of pieces along u and along v.
    var pieceCounts: (u: Int, v: Int) { get }
}

internal extension ParametricSurface {
    /// The pieces adaptive segmentation starts probing from: the surface's own, or for a surface that doesn't say,
    /// eight in each direction.
    var adaptivePieceCounts: (u: Int, v: Int) {
        (self as? any ParametricSurfacePieces)?.pieceCounts ?? (8, 8)
    }
}

public extension ParametricSurface {
    /// Samples the surface as a grid of points.
    ///
    /// - Parameter segmentation: Controls how finely the surface is sampled. Fixed segmentation samples a uniform
    ///   grid with that many segments in each direction. Adaptive segmentation splits the grid where the surface
    ///   turns, following the same rule as curves: only while a cell is both larger than the minimum size and the
    ///   surface turns across it by more than the minimum angle, so a flat surface stays a single cell.
    /// - Returns: The sampled points, as rows along `u`, each holding the points along `v`.
    func points(segmentation: Segmentation) -> [[Vector3D]] {
        switch segmentation {
        case .fixed(let count):
            return uniformGrid(uCount: count, vCount: count)
        case .adaptive(let minAngle, let minSize):
            return adaptiveGrid(minAngle: minAngle, minSize: minSize)
        }
    }
}

private extension ParametricSurface {
    func uniformGrid(uCount: Int, vCount: Int) -> [[Vector3D]] {
        let uSteps = (0...uCount).map { Double($0) / Double(uCount) }
        let vSteps = (0...vCount).map { Double($0) / Double(vCount) }
        return uSteps.map { u in
            vSteps.map { v in
                point(atFraction: Vector2D(u, v))
            }
        }
    }

    func adaptiveGrid(minAngle: Angle, minSize: Double) -> [[Vector3D]] {
        // Start from the surface's own pieces, such as the rows of an interpolating surface or the knot spans of a
        // spline surface, so that each is probed and nothing between two probes goes unseen.
        let start = adaptivePieceCounts
        var uSteps = Self.evenSteps(count: start.u)
        var vSteps = Self.evenSteps(count: start.v)

        // How many pieces the surface needs along a line between two points of the domain, given as fractions. The
        // line is probed for how far it turns, and also for how far the surface's normal turns along it: a twisted
        // surface can be straight along both u and v, like a hyperbolic paraboloid, and only its normal turns.
        func pieces(from a: Vector2D, to b: Vector2D) -> Int {
            let fractions = (0...4).map { a + (b - a) * (Double($0) / 4) }
            let probes = fractions.map { point(atFraction: $0) }
            let (length, lineTurn) = Segmentation.lengthAndTurn(across: probes)

            // Each normal from the line's own direction there and a short step across it, which past the domain's
            // edge lands on the surface's extension.
            let along = b - a
            let across = Vector2D(-along.y, along.x).normalized * 1e-4
            let normals = fractions.indices.map { index in
                let tangent = probes[min(index + 1, probes.count - 1)] - probes[max(index - 1, 0)]
                return tangent × (point(atFraction: fractions[index] + across) - probes[index])
            }
            let normalTurn = normals.paired().reduce(0.0) { sum, pair in
                guard pair.0.magnitude > 1e-18, pair.1.magnitude > 1e-18 else { return sum }
                return sum + Segmentation.angle(between: pair.0, and: pair.1)
            }
            return Segmentation.adaptivePieceCount(
                length: length, turn: max(lineTurn, normalTurn), minAngle: minAngle, minSize: minSize
            )
        }

        // Each interval is probed along a fixed set of lines across it, four per piece of the surface: how sharply
        // the surface turns one way only changes smoothly the other way, and a fixed set means an interval's answer
        // never changes, so each one is worked out once, however many rounds of splitting it survives.
        let uProbeLines = Self.evenSteps(count: 4 * start.v), vProbeLines = Self.evenSteps(count: 4 * start.u)
        var uKnown: [Vector2D: Int] = [:], vKnown: [Vector2D: Int] = [:]

        for _ in 0..<16 {
            let uPieces = zip(uSteps, uSteps.dropFirst()).map { a, b in
                if let known = uKnown[Vector2D(a, b)] { return known }
                let needed = uProbeLines.map { v in pieces(from: Vector2D(a, v), to: Vector2D(b, v)) }.max() ?? 1
                uKnown[Vector2D(a, b)] = needed
                return needed
            }
            let vPieces = zip(vSteps, vSteps.dropFirst()).map { a, b in
                if let known = vKnown[Vector2D(a, b)] { return known }
                let needed = vProbeLines.map { u in pieces(from: Vector2D(u, a), to: Vector2D(u, b)) }.max() ?? 1
                vKnown[Vector2D(a, b)] = needed
                return needed
            }

            guard uPieces.contains(where: { $0 > 1 }) || vPieces.contains(where: { $0 > 1 }) else { break }
            uSteps = Self.splitting(uSteps, into: uPieces)
            vSteps = Self.splitting(vSteps, into: vPieces)
        }

        return uSteps.map { u in
            vSteps.map { v in
                point(atFraction: Vector2D(u, v))
            }
        }
    }

    static func evenSteps(count: Int) -> [Double] {
        let count = max(count, 1)
        return (0...count).map { Double($0) / Double(count) }
    }

    // Splits each interval between two steps evenly into the given number of pieces.
    static func splitting(_ steps: [Double], into pieces: [Int]) -> [Double] {
        zip(steps, steps.dropFirst()).enumerated().flatMap { index, interval in
            (0..<pieces[index]).map { interval.0 + (interval.1 - interval.0) * Double($0) / Double(pieces[index]) }
        } + [steps.last!]
    }
}
