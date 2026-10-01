import Foundation

extension MeshOffset {
    /// The triangles around each vertex, in one flat array: no allocation per vertex, and safe to read from every core
    struct VertexFans {
        let offsets: [Int]
        let members: [Int]

        init(faces: [Face], vertexCount: Int) {
            var counts = [Int](repeating: 0, count: vertexCount + 1)
            for face in faces { counts[face.0 + 1] += 1; counts[face.1 + 1] += 1; counts[face.2 + 1] += 1 }
            for v in 0..<vertexCount { counts[v + 1] += counts[v] }
            var next = counts
            var members = [Int](repeating: 0, count: 3 * faces.count)
            for (index, face) in faces.enumerated() {
                members[next[face.0]] = index; next[face.0] += 1
                members[next[face.1]] = index; next[face.1] += 1
                members[next[face.2]] = index; next[face.2] += 1
            }
            offsets = counts
            self.members = members
        }

        /// Runs body with the offsets and members as buffers, which concurrent loops can read without retaining them
        func withBuffers<R>(_ body: (UnsafeBufferPointer<Int>, UnsafeBufferPointer<Int>) -> R) -> R {
            offsets.withUnsafeBufferPointer { offsets in members.withUnsafeBufferPointer { members in body(offsets, members) } }
        }

        /// The triangles around v that also have w as a corner
        func faces(around v: Int, with w: Int, in faces: [Face]) -> [Int] {
            var found: [Int] = []
            for n in offsets[v]..<offsets[v + 1] {
                let face = faces[members[n]]
                if face.0 == w || face.1 == w || face.2 == w { found.append(members[n]) }
            }
            return found
        }

        /// Edges used more one way than the other, such as a hole's rim: each as the way it's used more, and by how
        /// many uses
        func unbalancedEdges(in faces: [Face]) -> [(from: Int, to: Int, surplus: Int)] {
            let vertexCount = offsets.count - 1
            return offsets.withUnsafeBufferPointer { offsetBuffer in
            members.withUnsafeBufferPointer { memberBuffer in
            faces.withUnsafeBufferPointer { faceBuffer in
                nonisolated(unsafe) let offsets = offsetBuffer, members = memberBuffer, faces = faceBuffer
                return ConcurrentLoop.collect(vertexCount) { (v: Int, found: inout [(from: Int, to: Int, surplus: Int)]) in
                    let first = offsets[v], end = offsets[v + 1]
                    var n = first
                    while n < end {
                        let face = faces[members[n]]
                        var k = 0
                        while k < 3 {
                            let w = k == 0 ? face.0 : k == 1 ? face.1 : face.2
                            k += 1
                            guard w > v else { continue }
                            // Counted once, at its first triangle around v
                            var forward = 0, backward = 0, earlier = false
                            var m = first
                            while m < end {
                                let other = faces[members[m]]
                                if other.0 == w || other.1 == w || other.2 == w {
                                    if m < n { earlier = true }
                                    if (other.0 == v && other.1 == w) || (other.1 == v && other.2 == w) || (other.2 == v && other.0 == w) {
                                        forward += 1
                                    } else {
                                        backward += 1
                                    }
                                }
                                m += 1
                            }
                            if earlier || forward == backward { continue }
                            found.append(forward > backward ? (v, w, forward - backward) : (w, v, backward - forward))
                        }
                        n += 1
                    }
                }
            }
            }
            }
        }

        /// Edges used by other than two triangles, as (lower, higher) vertex pairs
        func irregularEdges(in faces: [Face]) -> [(Int, Int)] {
            let vertexCount = offsets.count - 1
            return offsets.withUnsafeBufferPointer { offsetBuffer in
            members.withUnsafeBufferPointer { memberBuffer in
            faces.withUnsafeBufferPointer { faceBuffer in
                nonisolated(unsafe) let offsets = offsetBuffer, members = memberBuffer, faces = faceBuffer
                return ConcurrentLoop.collect(vertexCount) { (v: Int, found: inout [(Int, Int)]) in
                    let first = offsets[v], end = offsets[v + 1]
                    var n = first
                    while n < end {
                        let face = faces[members[n]]
                        var k = 0
                        while k < 3 {
                            let w = k == 0 ? face.0 : k == 1 ? face.1 : face.2
                            k += 1
                            guard w > v else { continue }
                            // Counted once, at its first triangle around v
                            var uses = 0, earlier = false
                            var m = first
                            while m < end {
                                let other = faces[members[m]]
                                if other.0 == w || other.1 == w || other.2 == w {
                                    if m < n { earlier = true }
                                    uses += 1
                                }
                                m += 1
                            }
                            if !earlier && uses != 2 { found.append((v, w)) }
                        }
                        n += 1
                    }
                }
            }
            }
            }
        }
    }
}
