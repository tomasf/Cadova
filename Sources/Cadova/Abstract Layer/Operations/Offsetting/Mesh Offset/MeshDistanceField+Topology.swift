import Foundation

extension MeshDistanceField {
    static func edgeKey(_ a: Int, _ b: Int) -> UInt64 {
        a < b ? UInt64(a) << 32 | UInt64(b) : UInt64(b) << 32 | UInt64(a)
    }

    /// The faces around each vertex, in one flat array, to find the faces sharing each edge without a table of edges
    /// Raw buffers, not arrays: it's read from every core at once, and in unoptimized builds every array access
    /// would retain and release the storage, all cores contending for its reference count. The one who creates it
    /// deallocates it.
    struct Topology: @unchecked Sendable {
        let faces: UnsafeBufferPointer<Face>
        let offsets: UnsafeBufferPointer<Int>
        let members: UnsafeBufferPointer<Int>

        func deallocate() {
            faces.deallocate(); offsets.deallocate(); members.deallocate()
        }

        init(vertexCount: Int, faces: [Face]) {
            self.faces = MeshDistanceField.buffer(faces)
            var counts = [Int](repeating: 0, count: vertexCount + 1)
            for face in faces { counts[face.0 + 1] += 1; counts[face.1 + 1] += 1; counts[face.2 + 1] += 1 }
            var v = 0
            while v < vertexCount { counts[v + 1] += counts[v]; v += 1 }
            var next = counts
            var members = [Int](repeating: 0, count: 3 * faces.count)
            var index = 0
            while index < faces.count {
                let face = faces[index]
                members[next[face.0]] = index; next[face.0] += 1
                members[next[face.1]] = index; next[face.1] += 1
                members[next[face.2]] = index; next[face.2] += 1
                index += 1
            }
            offsets = MeshDistanceField.buffer(counts)
            self.members = MeshDistanceField.buffer(members)
        }

        /// Calls body with every other face sharing edge k of a face (from corner k to k + 1)
        func forEachSharing(face index: Int, edge k: Int, _ body: (Int) -> Void) {
            let face = faces[index]
            let a = k == 0 ? face.0 : k == 1 ? face.1 : face.2
            let b = k == 0 ? face.1 : k == 1 ? face.2 : face.0
            var n = offsets[a]
            while n < offsets[a + 1] {
                let other = faces[members[n]]
                if members[n] != index && (other.0 == b || other.1 == b || other.2 == b) { body(members[n]) }
                n += 1
            }
        }
    }
}
