import Foundation

/// A sparse octree over an integer grid. Nodes that can't contain the surface are left empty (no leaf, no
/// children); the others end as leaves.
internal struct OffsetOctree {
    struct Node {
        let i: Int, j: Int, k: Int
        let size: Int
        var child = -1   // index of the first of eight children
        var leaf = -1
    }

    struct Leaf {
        let i: Int, j: Int, k: Int
        /// Zero once the leaf has been split or merged away
        var size: Int
        let node: Int
    }

    /// The grid is `extent` units along each axis
    let extent: Int
    var nodes: [Node]
    var leaves: [Leaf] = []

    init(extent: Int) {
        self.extent = extent
        nodes = [Node(i: 0, j: 0, k: 0, size: extent)]
    }

    mutating func makeLeaf(node index: Int) {
        let node = nodes[index]
        nodes[index].leaf = leaves.count
        leaves.append(Leaf(i: node.i, j: node.j, k: node.k, size: node.size, node: index))
    }

    /// Adds eight children to a node and returns the index of the first
    mutating func subdivide(node index: Int) -> Int {
        let node = nodes[index]
        let first = nodes.count
        let half = node.size / 2
        nodes[index].child = first
        for c in 0..<8 {
            nodes.append(Node(i: node.i + (c & 1 != 0 ? half : 0), j: node.j + (c & 2 != 0 ? half : 0), k: node.k + (c & 4 != 0 ? half : 0), size: half))
        }
        return first
    }

    /// A leaf found by ``locate(_:_:_:)`` (nil in an empty region), and the size of the node found there, empty or not.
    /// (A struct rather than a tuple: unoptimized builds look up tuple metadata at every generic boundary.)
    struct Location {
        let leaf: Int?
        let size: Int
    }

    /// The leaf containing a point in grid units
    func locate(_ x: Double, _ y: Double, _ z: Double) -> Location {
        nodes.withUnsafeBufferPointer { Self.locate(x, y, z, in: $0, extent: extent) }
    }

    /// The same, over the nodes' storage: callers doing many lookups take the buffer once, since each access to the
    /// array retains it, and from many threads at once, that dominates in unoptimized builds
    static func locate(_ x: Double, _ y: Double, _ z: Double, in nodes: UnsafeBufferPointer<Node>, extent: Int) -> Location {
        let limit = Double(extent)
        guard x >= 0, y >= 0, z >= 0, x < limit, y < limit, z < limit else { return Location(leaf: nil, size: extent) }
        var index = 0
        while true {
            let node = nodes[index]
            if node.leaf >= 0 { return Location(leaf: node.leaf, size: node.size) }
            if node.child < 0 { return Location(leaf: nil, size: node.size) }
            let half = Double(node.size / 2)
            let c = (x >= Double(node.i) + half ? 1 : 0) | (y >= Double(node.j) + half ? 2 : 0) | (z >= Double(node.k) + half ? 4 : 0)
            index = node.child + c
        }
    }

    /// The node of the given size containing a grid point, or the larger leaf or empty node covering it
    func node(at i: Int, _ j: Int, _ k: Int, size: Int) -> Int? {
        nodes.withUnsafeBufferPointer { Self.node(at: i, j, k, size: size, in: $0, extent: extent) }
    }

    private static func node(at i: Int, _ j: Int, _ k: Int, size: Int, in nodes: UnsafeBufferPointer<Node>, extent: Int) -> Int? {
        guard i >= 0, j >= 0, k >= 0, i < extent, j < extent, k < extent else { return nil }
        var index = 0
        while nodes[index].size > size && nodes[index].child >= 0 {
            let node = nodes[index]
            let half = node.size / 2
            index = node.child + ((i >= node.i + half ? 1 : 0) | (j >= node.j + half ? 2 : 0) | (k >= node.k + half ? 4 : 0))
        }
        return index
    }

    /// Whether any leaf touching the cube (i, j, k, size) from outside is smaller than half its size
    func hasMuchSmallerNeighbor(_ i: Int, _ j: Int, _ k: Int, size: Int) -> Bool {
        // Plain counted loops: range iteration is generic, and slow in unoptimized builds
        nodes.withUnsafeBufferPointer { nodes in
            var neighbor = 0
            while neighbor < 27 {
                let dx = neighbor % 3 - 1, dy = neighbor / 3 % 3 - 1, dz = neighbor / 9 - 1
                neighbor += 1
                if dx == 0 && dy == 0 && dz == 0 { continue }
                guard let index = Self.node(at: i + dx * size, j + dy * size, k + dz * size, size: size, in: nodes, extent: extent) else { continue }
                let other = nodes[index]
                guard other.size == size, other.child >= 0 else { continue }
                // The neighbor's children that face this cube, split once more, are too small
                var c = 0
                while c < 8 {
                    let cx = c & 1, cy = c >> 1 & 1, cz = c >> 2 & 1
                    let facing = !((dx == 1 && cx == 1) || (dx == -1 && cx == 0) || (dy == 1 && cy == 1) || (dy == -1 && cy == 0) || (dz == 1 && cz == 1) || (dz == -1 && cz == 0))
                    if facing && nodes[other.child + c].child >= 0 { return true }
                    c += 1
                }
            }
            return false
        }
    }
}
