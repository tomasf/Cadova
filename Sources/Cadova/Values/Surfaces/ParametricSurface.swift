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
    /// - Parameter uv: The surface parameters, with `u` (`x`) within ``uDomain`` and `v` (`y`) within
    ///   ``vDomain``.
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
}

public extension ParametricSurface {
    /// Samples the surface as a grid of points.
    ///
    /// - Parameter segmentation: Controls how finely the surface is sampled. Fixed segmentation samples a uniform
    ///   grid with that many segments in each direction; adaptive segmentation subdivides until every cell is
    ///   smaller than the minimum size.
    /// - Returns: The sampled points, as rows along `u`, each holding the points along `v`.
    func points(segmentation: Segmentation) -> [[Vector3D]] {
        switch segmentation {
        case .fixed(let count):
            return uniformGrid(uCount: count, vCount: count)
        case .adaptive(_, let minSize):
            return adaptiveGrid(minSize: minSize)
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

    func adaptiveGrid(minSize: Double) -> [[Vector3D]] {
        var uSteps: [Double] = [0.0, 1.0]
        var vSteps: [Double] = [0.0, 1.0]
        var needsSubdivision = true

        while needsSubdivision {
            // Sample current grid
            let pointsGrid = uSteps.map { u in
                vSteps.map { v in
                    point(atFraction: Vector2D(u, v))
                }
            }

            needsSubdivision = false
            var uSubdivide = Set<Int>()
            var vSubdivide = Set<Int>()

            // Check all quads
            for u in 0..<(uSteps.count - 1) {
                for v in 0..<(vSteps.count - 1) {
                    let p00 = pointsGrid[u][v]
                    let p10 = pointsGrid[u + 1][v]
                    let p01 = pointsGrid[u][v + 1]
                    let p11 = pointsGrid[u + 1][v + 1]

                    let dU0 = p00.distance(to: p10)
                    let dU1 = p01.distance(to: p11)
                    let dV0 = p00.distance(to: p01)
                    let dV1 = p10.distance(to: p11)
                    let diag1 = p00.distance(to: p11)
                    let diag2 = p10.distance(to: p01)

                    let maxU = max(dU0, dU1)
                    let maxV = max(dV0, dV1)

                    if [dU0, dU1, dV0, dV1, diag1, diag2].contains(where: { $0 > minSize }) {
                        needsSubdivision = true
                        if maxU >= maxV {
                            uSubdivide.insert(u)
                        } else {
                            vSubdivide.insert(v)
                        }
                    }
                }
            }

            // Insert midpoints where needed
            if needsSubdivision {
                uSteps = insertMidpoints(steps: uSteps, at: uSubdivide)
                vSteps = insertMidpoints(steps: vSteps, at: vSubdivide)
            }
        }

        return uSteps.map { u in
            vSteps.map { v in
                point(atFraction: Vector2D(u, v))
            }
        }
    }

    func insertMidpoints(steps: [Double], at indices: Set<Int>) -> [Double] {
        var newSteps: [Double] = []
        for i in 0..<(steps.count - 1) {
            newSteps.append(steps[i])
            if indices.contains(i) {
                let mid = (steps[i] + steps[i + 1]) / 2
                newSteps.append(mid)
            }
        }
        newSteps.append(steps.last!)
        return newSteps.sorted()
    }
}
