import Foundation

extension MeshOffset {
    /// Hermite data on every sign-changing minimal edge, and each leaf's planes
    func computeFits() {
        let all = minimalEdges()
        // The edges that cross, and those among them with no crossing found yet
        let (crossingEdges, missingEdges) = all.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let all = buffer
            let crossing = ConcurrentLoop.collect(all.count) { (n: Int, found: inout [Int]) in
                if self.crosses(all[n]).crosses { found.append(n) }
            }
            let missing = crossing.withUnsafeBufferPointer { crossingBuffer in
                nonisolated(unsafe) let crossing = crossingBuffer
                return ConcurrentLoop.collect(crossing.count) { (n: Int, found: inout [Edge]) in
                    let edge = all[crossing[n]]
                    if self.knownCrossings.value(for: Self.spanKey(edge.key, length: edge.length)) == nil { found.append(edge) }
                }
            }
            return (crossing, missing)
        }
        let missing = missingEdges
        let found = ConcurrentLoop.map(missing.count) { self.crossing(on: missing[$0]) }
        // Stored in order, and indexed shard by shard in parallel
        let base = crossingStore.count
        crossingStore.append(contentsOf: found)
        let index = crossingIndex
        let keys = ConcurrentLoop.map(missing.count) { Self.spanKey(missing[$0].key, length: missing[$0].length) }
        let shards = ConcurrentLoop.map(keys.count) { UInt8(truncatingIfNeeded: index.shard(of: keys[$0])) }
        keys.withUnsafeBufferPointer { keyBuffer in
            shards.withUnsafeBufferPointer { shardBuffer in
                nonisolated(unsafe) let keys = keyBuffer, shards = shardBuffer
                ConcurrentLoop.perform(index.shardCount) { shard in
                    var n = 0
                    while n < keys.count {
                        if Int(shards[n]) == shard { index.set(Double(base + n), for: keys[n]) }
                        n += 1
                    }
                }
            }
        }

        // Each crossing's place in the store, looked up once rather than by every leaf around it
        let stored = crossingEdges.withUnsafeBufferPointer { crossingBuffer in
            all.withUnsafeBufferPointer { allBuffer in
                nonisolated(unsafe) let crossing = crossingBuffer, all = allBuffer
                return ConcurrentLoop.map(crossing.count) { n -> Int in
                    let edge = all[crossing[n]]
                    return Int(self.knownCrossings.value(for: Self.spanKey(edge.key, length: edge.length))!)
                }
            }
        }

        // Each leaf's planes, from the crossings on edges around it: the crossings grouped by leaf (each distinct
        // leaf around an edge once, in edge order), then every leaf's summed on its own
        let leafCount = octree.leaves.count
        var offsets = [Int](repeating: 0, count: leafCount + 1)
        var members: [Int32] = []
        crossingEdges.withUnsafeBufferPointer { crossing in
            all.withUnsafeBufferPointer { all in
                func forEachLeaf(_ n: Int, _ body: (Int) -> Void) {
                    let a = all[crossing[n]].around
                    if a.0 >= 0 { body(a.0) }
                    if a.1 >= 0 && a.1 != a.0 { body(a.1) }
                    if a.2 >= 0 && a.2 != a.0 && a.2 != a.1 { body(a.2) }
                    if a.3 >= 0 && a.3 != a.0 && a.3 != a.1 && a.3 != a.2 { body(a.3) }
                }
                var n = 0
                while n < crossing.count { forEachLeaf(n) { offsets[$0 + 1] += 1 }; n += 1 }
                var leaf = 0
                while leaf < leafCount { offsets[leaf + 1] += offsets[leaf]; leaf += 1 }
                var next = offsets
                members = [Int32](repeating: 0, count: offsets[leafCount])
                n = 0
                while n < crossing.count {
                    forEachLeaf(n) { members[next[$0]] = Int32(n); next[$0] += 1 }
                    n += 1
                }
            }
        }
        var accumulated = offsets.withUnsafeBufferPointer { offsetBuffer in
            members.withUnsafeBufferPointer { memberBuffer in
            stored.withUnsafeBufferPointer { storedBuffer in
            crossingStore.withUnsafeBufferPointer { storeBuffer in
                nonisolated(unsafe) let offsets = offsetBuffer, members = memberBuffer, stored = storedBuffer, store = storeBuffer
                return ConcurrentLoop.map(leafCount) { leaf -> PlaneFit in
                    var fit = PlaneFit()
                    var m = offsets[leaf]
                    while m < offsets[leaf + 1] {
                        let result = store[stored[Int(members[m])]]
                        fit.add(point: result.point, normal: result.normal)
                        m += 1
                    }
                    return fit
                }
            }
            }
            }
        }
        for (leaf, merge) in merges where leaf < accumulated.count {
            accumulated[leaf] = merge.fit
        }
        fits = accumulated
        fittedEdges = (all, crossingEdges)
    }
}
