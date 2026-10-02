import Foundation

extension OffsetCorners {
    /// Convex pieces, searchable by a bounding volume hierarchy over their boxes. Stored in raw buffers, since
    /// queries run concurrently from every core (see ``MeshDistanceField``).
    final class PieceSet: @unchecked Sendable {
        struct Node {
            var lower: Vector3D, upper: Vector3D
            var left = -1, right = -1, first = 0, count = 0
        }
        struct Bounds { let lower: Vector3D; let upper: Vector3D; let firstPlane: Int; let planeCount: Int }

        let planes: UnsafeMutableBufferPointer<Plane>
        let bounds: UnsafeMutableBufferPointer<Bounds>
        let nodes: UnsafeMutableBufferPointer<Node>
        let order: UnsafeMutableBufferPointer<Int>

        init(_ pieces: [Piece]) {
            var allPlanes: [Plane] = []
            var allBounds: [Bounds] = []
            for piece in pieces {
                allBounds.append(Bounds(lower: piece.lower, upper: piece.upper, firstPlane: allPlanes.count, planeCount: piece.planes.count))
                allPlanes += piece.planes
            }
            var order = Array(pieces.indices)
            var nodes: [Node] = []
            func build(_ first: Int, _ count: Int) -> Int {
                let index = nodes.count
                var lower = allBounds[order[first]].lower, upper = allBounds[order[first]].upper
                for i in first..<(first + count) { lower = .min(lower, allBounds[order[i]].lower); upper = .max(upper, allBounds[order[i]].upper) }
                nodes.append(Node(lower: lower, upper: upper))
                if count <= 4 {
                    nodes[index].first = first
                    nodes[index].count = count
                    return index
                }
                let extent = upper - lower
                let axis = extent.x >= extent.y && extent.x >= extent.z ? 0 : (extent.y >= extent.z ? 1 : 2)
                order[first..<(first + count)].sort { (allBounds[$0].lower[axis] + allBounds[$0].upper[axis]) < (allBounds[$1].lower[axis] + allBounds[$1].upper[axis]) }
                let left = build(first, count / 2)
                let right = build(first + count / 2, count - count / 2)
                nodes[index].left = left
                nodes[index].right = right
                return index
            }
            if !pieces.isEmpty { _ = build(0, pieces.count) }
            planes = .allocate(capacity: max(allPlanes.count, 1)); _ = planes.initialize(from: allPlanes)
            bounds = .allocate(capacity: max(allBounds.count, 1)); _ = bounds.initialize(from: allBounds)
            self.nodes = .allocate(capacity: max(nodes.count, 1)); _ = self.nodes.initialize(from: nodes)
            self.order = .allocate(capacity: max(order.count, 1)); _ = self.order.initialize(from: order)
            isEmpty = pieces.isEmpty
        }

        let isEmpty: Bool

        deinit {
            planes.deallocate(); bounds.deallocate(); nodes.deallocate(); order.deallocate()
        }

        /// Distance from (x, y, z) to a box, or zero inside
        static func boxDistance(_ lower: Vector3D, _ upper: Vector3D, _ x: Double, _ y: Double, _ z: Double) -> Double {
            let dx = x < lower.x ? lower.x - x : (x > upper.x ? x - upper.x : 0)
            let dy = y < lower.y ? lower.y - y : (y > upper.y ? y - upper.y : 0)
            let dz = z < lower.z ? lower.z - z : (z > upper.z ? z - upper.z : 0)
            return (dx * dx + dy * dy + dz * dz).squareRoot()
        }

        /// The gradient of the distance to a box, outside it
        static func boxGradient(_ lower: Vector3D, _ upper: Vector3D, _ p: Vector3D) -> Vector3D {
            let d = Vector3D(
                p.x < lower.x ? p.x - lower.x : (p.x > upper.x ? p.x - upper.x : 0),
                p.y < lower.y ? p.y - lower.y : (p.y > upper.y ? p.y - upper.y : 0),
                p.z < lower.z ? p.z - lower.z : (p.z > upper.z ? p.z - upper.z : 0)
            )
            return d.safelyNormalized
        }

        func hasBox(within radius: Double, of p: Vector3D) -> Bool {
            guard !isEmpty else { return false }
            let x = p.x, y = p.y, z = p.z
            return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
                var top = 1
                stack[0] = 0
                while top > 0 {
                    top -= 1
                    let node = nodes[stack[top]]
                    if Self.boxDistance(node.lower, node.upper, x, y, z) > radius { continue }
                    if node.left < 0 {
                        var i = node.first
                        while i < node.first + node.count {
                            let piece = bounds[order[i]]
                            if Self.boxDistance(piece.lower, piece.upper, x, y, z) <= radius { return true }
                            i += 1
                        }
                        continue
                    }
                    stack[top] = node.left; stack[top + 1] = node.right; top += 2
                }
                return false
            }
        }

        /// The smallest piece value at p, clamped to reach, and its gradient. A piece's value is the larger of its
        /// largest plane distance and its box distance (outside the box): continuous, zero on its boundary, and
        /// never below the box distance, so boxes away from p can be skipped. Scalars and counted loops throughout:
        /// this runs for every sample, in unoptimized builds too.
        func value(at p: Vector3D, reach: Double) -> (value: Double, gradient: Vector3D) {
            guard !isEmpty else { return (reach, .zero) }
            let x = p.x, y = p.y, z = p.z
            var best = reach
            var bestPiece = -1, bestPlane = -1   // the plane giving the best value, or -1 for the piece's box
            withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
                var top = 1
                stack[0] = 0
                while top > 0 {
                    top -= 1
                    let node = nodes[stack[top]]
                    let away = Self.boxDistance(node.lower, node.upper, x, y, z)
                    // Inside a box, a piece can be anything: only boxes away from p can be skipped
                    if away > 0 && away >= best { continue }
                    if node.left < 0 {
                        var i = node.first
                        while i < node.first + node.count {
                            let piece = bounds[order[i]]
                            i += 1
                            // The piece's value is its largest plane distance, so once one plane reaches the best
                            // so far, the piece can't improve on it
                            var largest = -Double.infinity, largestPlane = -1
                            var k = piece.firstPlane
                            while k < piece.firstPlane + piece.planeCount && largest < best {
                                let plane = planes[k]
                                let d = plane.normal.x * x + plane.normal.y * y + plane.normal.z * z - plane.offset
                                if d > largest { largest = d; largestPlane = k }
                                k += 1
                            }
                            guard largest < best else { continue }
                            let box = Self.boxDistance(piece.lower, piece.upper, x, y, z)
                            if box > 0 && box > largest { largest = box; largestPlane = -1 }
                            if largest < best { best = largest; bestPiece = order[i - 1]; bestPlane = largestPlane }
                        }
                        continue
                    }
                    stack[top] = node.left; stack[top + 1] = node.right; top += 2
                }
            }
            guard bestPiece >= 0 else { return (best, .zero) }
            if bestPlane >= 0 { return (best, planes[bestPlane].normal) }
            let piece = bounds[bestPiece]
            return (best, Self.boxGradient(piece.lower, piece.upper, p))
        }
    }
}
