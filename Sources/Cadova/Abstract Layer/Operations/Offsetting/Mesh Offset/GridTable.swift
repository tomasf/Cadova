import Foundation

/// A hash table from grid keys to doubles, by open addressing over raw memory.
///
/// Offsetting looks values up millions of times, from every core. A dictionary works too, but in unoptimized builds
/// its generic hashing and the reference counting of its storage cost more than the geometry; this stays fast there.
/// Reads are safe to run concurrently. Writes are not, except that the table is split into shards by key, and writes
/// to different shards can run concurrently.
internal final class GridTable: @unchecked Sendable {
    fileprivate struct Shard {
        var keys: UnsafeMutablePointer<UInt64>
        var values: UnsafeMutablePointer<Double>
        var capacity: Int
        var count = 0

        init(capacity minimum: Int) {
            capacity = 1
            while capacity < minimum * 2 { capacity <<= 1 }
            keys = .allocate(capacity: capacity)
            keys.initialize(repeating: 0, count: capacity)
            values = .allocate(capacity: capacity)
            values.initialize(repeating: 0, count: capacity)
        }

        func deallocate() {
            keys.deallocate()
            values.deallocate()
        }
    }

    private let shards: UnsafeMutableBufferPointer<Shard>
    /// Shards are chosen by the top bits of the key's hash, slots by the bits below
    private let shardShift: UInt64
    let shardCount: Int

    var count: Int { shards.reduce(0) { $0 + $1.count } }

    // Keys are stored plus one, so zero can mark an empty slot
    init(capacity minimum: Int = 1024, shards shardCount: Int = 1) {
        precondition(shardCount > 0 && shardCount & (shardCount - 1) == 0, "Shard counts are powers of two")
        self.shardCount = shardCount
        shardShift = UInt64(64 - shardCount.trailingZeroBitCount)
        shards = .allocate(capacity: shardCount)
        for s in 0..<shardCount {
            (shards.baseAddress! + s).initialize(to: Shard(capacity: max(16, minimum / shardCount)))
        }
    }

    deinit {
        for s in 0..<shardCount { shards[s].deallocate() }
        shards.deallocate()
    }

    fileprivate static func hash(_ key: UInt64) -> UInt64 {
        // Fibonacci hashing spreads the structured grid keys over the table
        key &* 0x9E37_79B9_7F4A_7C15
    }

    /// The shard a key belongs to
    func shard(of key: UInt64) -> Int {
        shardCount == 1 ? 0 : Int(truncatingIfNeeded: Self.hash(key) >> shardShift)
    }

    private func slot(_ hash: UInt64, mask: Int) -> Int {
        Int(truncatingIfNeeded: hash >> 20) & mask
    }

    func value(for key: UInt64) -> Double? {
        reader.value(for: key)
    }

    /// Reads the table without referencing it: holding the table itself, every read from every core retains and
    /// releases it in unoptimized builds. Valid as long as the table lives; reads see writes made after it's taken.
    var reader: Reader { Reader(shards: shards, shardShift: shardShift, shardCount: shardCount) }

    struct Reader: @unchecked Sendable {
        fileprivate let shards: UnsafeMutableBufferPointer<Shard>
        fileprivate let shardShift: UInt64
        fileprivate let shardCount: Int

        func value(for key: UInt64) -> Double? {
            let hash = GridTable.hash(key)
            let shard = shards[shardCount == 1 ? 0 : Int(truncatingIfNeeded: hash >> shardShift)]
            let stored = key &+ 1, mask = shard.capacity - 1
            var slot = Int(truncatingIfNeeded: hash >> 20) & mask
            while true {
                let present = shard.keys[slot]
                if present == stored { return shard.values[slot] }
                if present == 0 { return nil }
                slot = (slot + 1) & mask
            }
        }
    }

    func set(_ value: Double, for key: UInt64) {
        let index = shard(of: key)
        if (shards[index].count + 1) * 2 > shards[index].capacity { grow(index) }
        let shard = shards[index]
        let stored = key &+ 1, mask = shard.capacity - 1
        var slot = slot(Self.hash(key), mask: mask)
        while true {
            let present = shard.keys[slot]
            if present == stored { shard.values[slot] = value; return }
            if present == 0 {
                shard.keys[slot] = stored
                shard.values[slot] = value
                shards[index].count += 1
                return
            }
            slot = (slot + 1) & mask
        }
    }

    private func grow(_ index: Int) {
        let old = shards[index]
        shards[index] = Shard(capacity: old.capacity)
        for slot in 0..<old.capacity where old.keys[slot] != 0 {
            set(old.values[slot], for: old.keys[slot] &- 1)
        }
        old.deallocate()
    }
}
