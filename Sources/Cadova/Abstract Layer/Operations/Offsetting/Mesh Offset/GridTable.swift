import Foundation

/// A hash table from grid keys to doubles, by open addressing over raw memory.
///
/// Offsetting looks values up millions of times, from every core. A dictionary works too, but in unoptimized builds
/// its generic hashing and the reference counting of its storage cost more than the geometry; this stays fast there.
/// Reads are safe to run concurrently; writes are not.
internal final class GridTable: @unchecked Sendable {
    private var keys: UnsafeMutablePointer<UInt64>
    private var values: UnsafeMutablePointer<Double>
    private var capacity: Int
    private(set) var count = 0

    // Keys are stored plus one, so zero can mark an empty slot
    init(capacity minimum: Int = 1024) {
        capacity = 1
        while capacity < minimum * 2 { capacity <<= 1 }
        keys = .allocate(capacity: capacity)
        keys.initialize(repeating: 0, count: capacity)
        values = .allocate(capacity: capacity)
        values.initialize(repeating: 0, count: capacity)
    }

    deinit {
        keys.deallocate()
        values.deallocate()
    }

    private static func slot(for key: UInt64, mask: Int) -> Int {
        // Fibonacci hashing spreads the structured grid keys over the table
        Int(truncatingIfNeeded: (key &* 0x9E37_79B9_7F4A_7C15) >> 20) & mask
    }

    func value(for key: UInt64) -> Double? {
        let stored = key &+ 1, mask = capacity - 1
        var slot = Self.slot(for: key, mask: mask)
        while true {
            let present = keys[slot]
            if present == stored { return values[slot] }
            if present == 0 { return nil }
            slot = (slot + 1) & mask
        }
    }

    func set(_ value: Double, for key: UInt64) {
        if (count + 1) * 2 > capacity { grow() }
        let stored = key &+ 1, mask = capacity - 1
        var slot = Self.slot(for: key, mask: mask)
        while true {
            let present = keys[slot]
            if present == stored { values[slot] = value; return }
            if present == 0 {
                keys[slot] = stored
                values[slot] = value
                count += 1
                return
            }
            slot = (slot + 1) & mask
        }
    }

    private func grow() {
        let oldKeys = keys, oldValues = values, oldCapacity = capacity
        capacity *= 2
        keys = .allocate(capacity: capacity)
        keys.initialize(repeating: 0, count: capacity)
        values = .allocate(capacity: capacity)
        values.initialize(repeating: 0, count: capacity)
        count = 0
        for slot in 0..<oldCapacity where oldKeys[slot] != 0 {
            set(oldValues[slot], for: oldKeys[slot] &- 1)
        }
        oldKeys.deallocate()
        oldValues.deallocate()
    }
}
