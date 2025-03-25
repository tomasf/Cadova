import Foundation

public struct BezierPatch: Sendable {
    let controlPoints: [[Vector3D]] // rows × columns

    public init(controlPoints: [[Vector3D]]) {
        precondition(!controlPoints.isEmpty)
        let columnCount = controlPoints[0].count
        precondition(columnCount >= 2, "Each row must have at least two control points")
        precondition(controlPoints.allSatisfy { $0.count == columnCount }, "All rows must have the same number of control points")
        self.controlPoints = controlPoints
    }

    /// Evaluate the point on the surface at parameters (u, v), both in 0...1 range
    internal func point(at u: Double, v: Double) -> Vector3D {
        // Step 1: Evaluate Bézier curves in v-direction (columns)
        let intermediatePoints: [Vector3D] = controlPoints.map { row in
            BezierCurve(controlPoints: row).point(at: v)
        }

        // Step 2: Evaluate Bézier curve in u-direction (rows)
        return BezierCurve(controlPoints: intermediatePoints).point(at: u)
    }

    /// Generates a grid of sampled points across the surface
    internal func points(uFacets: Int, vFacets: Int) -> [[Vector3D]] {
        let uSteps = (0...uFacets).map { Double($0) / Double(uFacets) }
        let vSteps = (0...vFacets).map { Double($0) / Double(vFacets) }

        return uSteps.map { u in
            vSteps.map { v in
                point(at: u, v: v)
            }
        }
    }

    /// Transform all control points using an affine transform
    func transformed(using transform: AffineTransform3D) -> Self {
        let transformedPoints = controlPoints.map { row in
            row.map { transform.apply(to: $0) }
        }
        return Self(controlPoints: transformedPoints)
    }
}

extension BezierPatch: CustomDebugStringConvertible {
    public var debugDescription: String {
        controlPoints
            .map { row in row.map { $0.debugDescription }.joined(separator: ", ") }
            .joined(separator: "\n")
    }
}

public extension BezierPatch {
    func points(facets: EnvironmentValues.Facets) -> [[Vector3D]] {
        switch facets {
        case .fixed(let count):
            return uniformGrid(uCount: count, vCount: count)
        case .dynamic(_, let minSize):
            return adaptiveGrid(minSize: minSize)
        }
    }

    private func uniformGrid(uCount: Int, vCount: Int) -> [[Vector3D]] {
        let uSteps = (0...uCount).map { Double($0) / Double(uCount) }
        let vSteps = (0...vCount).map { Double($0) / Double(vCount) }
        return uSteps.map { u in
            vSteps.map { v in
                point(at: u, v: v)
            }
        }
    }

    private func adaptiveGrid(minSize: Double) -> [[Vector3D]] {
        var uSteps: [Double] = [0.0, 1.0]
        var vSteps: [Double] = [0.0, 1.0]
        var needsSubdivision = true

        while needsSubdivision {
            // Sample current grid
            let pointsGrid = uSteps.map { u in
                vSteps.map { v in
                    point(at: u, v: v)
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

        // Final grid
        return uSteps.map { u in
            vSteps.map { v in
                point(at: u, v: v)
            }
        }
    }

    private func insertMidpoints(steps: [Double], at indices: Set<Int>) -> [Double] {
        var newSteps: [Double] = []
        for i in 0..<(steps.count - 1) {
            newSteps.append(steps[i])
            if indices.contains(i) {
                let mid = (steps[i] + steps[i + 1]) / 2
                newSteps.append(mid)
            }
        }
        newSteps.append(steps.last!) // Add final point
        return newSteps.sorted()
    }
}
