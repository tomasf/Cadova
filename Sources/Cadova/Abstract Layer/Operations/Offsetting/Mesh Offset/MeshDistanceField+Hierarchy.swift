import Foundation

extension MeshDistanceField {
    /// Builds the bounding volume hierarchy, splitting at the median centroid along the centroids' longest extent.
    /// Medians come from selection rather than sorting, and each node's box and dipole from its children.
    struct Hierarchy {
        // Raw buffers while building: array accesses in this recursion pay for uniqueness checks and reference
        // counting in unoptimized builds
        let coordinates: UnsafeMutableBufferPointer<Double>
        let faces: UnsafeMutableBufferPointer<Face>
        let orderBuffer: UnsafeMutableBufferPointer<Int>
        /// Three times each face's centroid, per axis
        let centroids: UnsafeMutableBufferPointer<Double>
        let faceCount: Int
        var nodes: [Node] = []
        var order: [Int] { Array(orderBuffer) }

        init(coordinates: [Double], faces: [Face]) {
            faceCount = faces.count
            self.coordinates = .allocate(capacity: max(coordinates.count, 1))
            _ = self.coordinates.initialize(from: coordinates)
            self.faces = .allocate(capacity: max(faces.count, 1))
            _ = self.faces.initialize(from: faces)
            orderBuffer = .allocate(capacity: max(faces.count, 1))
            centroids = .allocate(capacity: max(3 * faces.count, 1))
            nodes.reserveCapacity(2 * faces.count)
            var index = 0
            while index < faces.count {
                orderBuffer[index] = index
                let face = faces[index]
                var axis = 0
                while axis < 3 {
                    centroids[3 * index + axis] = coordinates[3 * face.0 + axis] + coordinates[3 * face.1 + axis] + coordinates[3 * face.2 + axis]
                    axis += 1
                }
                index += 1
            }
        }

        func deallocate() {
            coordinates.deallocate(); faces.deallocate(); orderBuffer.deallocate(); centroids.deallocate()
        }

        func vertex(_ v: Int) -> Vector3D {
            Vector3D(coordinates[3 * v], coordinates[3 * v + 1], coordinates[3 * v + 2])
        }

        /// Builds the tree over all faces, with its root first. The top levels split serially into subtrees of
        /// disjoint face ranges, which build in parallel into their own node lists and are then joined.
        mutating func build() {
            guard faceCount > 0 else { return }
            let serialLimit = max(1024, faceCount / 64)
            // Nodes above the subtrees, in creation order (parents before children), with where their faces start
            struct Pending { let index: Int; var left = -1, right = -1 }
            var pending: [Pending] = []
            var tasks: [(first: Int, count: Int, parent: Int, isLeft: Bool)] = []
            func split(_ first: Int, _ count: Int, parent: Int, isLeft: Bool) {
                if count <= serialLimit {
                    tasks.append((first, count, parent, isLeft))
                    return
                }
                let index = nodes.count
                nodes.append(Node(lower: .zero, upper: .zero))
                if parent >= 0 {
                    if isLeft { pending[parent].left = index } else { pending[parent].right = index }
                }
                let slot = pending.count
                pending.append(Pending(index: index))
                let middle = splitPoint(first: first, count: count)
                split(first, middle - first, parent: slot, isLeft: true)
                split(middle, first + count - middle, parent: slot, isLeft: false)
            }
            split(0, faceCount, parent: -1, isLeft: true)
            // The subtrees, each into its own list with its root first. Their face ranges are disjoint, so they
            // reorder their own parts of the shared order concurrently.
            nonisolated(unsafe) let builder = self
            let ranges = tasks.map { (first: $0.first, count: $0.count) }
            // Dispatched one per subtree: they're few and large, too few for a concurrent loop to split up
            var built = [[Node]](repeating: [], count: ranges.count)
            built.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let built = buffer
                DispatchQueue.concurrentPerform(iterations: ranges.count) { n in
                    var local: [Node] = []
                    local.reserveCapacity(2 * ranges[n].count / 3 + 1)
                    _ = builder.build(first: ranges[n].first, count: ranges[n].count, into: &local)
                    built[n] = local
                }
            }
            for (n, task) in tasks.enumerated() {
                let offset = nodes.count
                for var node in built[n] {
                    if node.left >= 0 { node.left += offset; node.right += offset }
                    nodes.append(node)
                }
                if task.parent >= 0 {
                    if task.isLeft { pending[task.parent].left = offset } else { pending[task.parent].right = offset }
                }
            }
            // The nodes above them, children first
            for entry in pending.reversed() {
                let l = nodes[entry.left], r = nodes[entry.right]
                let leftArea = l.weight, rightArea = r.weight
                nodes[entry.index] = Self.finished(lower: .min(l.lower, r.lower), upper: .max(l.upper, r.upper), area: l.area + r.area,
                                                   weightedCenter: l.center * leftArea + r.center * rightArea, totalArea: leftArea + rightArea)
                nodes[entry.index].left = entry.left
                nodes[entry.index].right = entry.right
            }
        }


        /// Builds the subtree over first..<first + count into a node list, and returns its root's index there
        func build(first: Int, count: Int, into nodes: inout [Node]) -> Int {
            let index = nodes.count
            nodes.append(Node(lower: .zero, upper: .zero))

            if count <= 4 {
                let seed = vertex(faces[orderBuffer[first]].0)
                var lower = seed, upper = seed
                var area = Vector3D.zero, weightedCenter = Vector3D.zero, totalArea = 0.0
                var i = first
                while i < first + count {
                    let face = faces[orderBuffer[i]]
                    let a = vertex(face.0), b = vertex(face.1), c = vertex(face.2)
                    lower = .min(lower, .min(a, .min(b, c)))
                    upper = .max(upper, .max(a, .max(b, c)))
                    let doubleArea = (b - a) × (c - a)
                    let weight = doubleArea.magnitude / 2
                    area = area + doubleArea * 0.5
                    weightedCenter = weightedCenter + (a + b + c) * (weight / 3)
                    totalArea += weight
                    i += 1
                }
                nodes[index] = Self.finished(lower: lower, upper: upper, area: area, weightedCenter: weightedCenter, totalArea: totalArea)
                nodes[index].first = first
                nodes[index].count = count
                return index
            }

            let middle = splitPoint(first: first, count: count)
            let left = build(first: first, count: middle - first, into: &nodes)
            let right = build(first: middle, count: first + count - middle, into: &nodes)
            let l = nodes[left], r = nodes[right]
            // Dipoles combine as sums; their weighted centers are recovered from center times area
            let leftArea = l.weight, rightArea = r.weight
            nodes[index] = Self.finished(lower: .min(l.lower, r.lower), upper: .max(l.upper, r.upper), area: l.area + r.area,
                                         weightedCenter: l.center * leftArea + r.center * rightArea, totalArea: leftArea + rightArea)
            nodes[index].left = left
            nodes[index].right = right
            return index
        }

        static func finished(lower: Vector3D, upper: Vector3D, area: Vector3D, weightedCenter: Vector3D, totalArea: Double) -> Node {
            let center = totalArea > 0 ? weightedCenter / totalArea : (lower + upper) / 2
            var radius = 0.0
            var corner = 0
            while corner < 8 {
                let point = Vector3D(corner & 1 == 0 ? lower.x : upper.x, corner & 2 == 0 ? lower.y : upper.y, corner & 4 == 0 ? lower.z : upper.z)
                radius = max(radius, (point - center).magnitude)
                corner += 1
            }
            return Node(lower: lower, upper: upper, area: area, center: center, radius: radius, weight: totalArea)
        }
    }
}
