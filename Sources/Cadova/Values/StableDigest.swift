import Foundation

/// A 128-bit content digest that identifies a value by what it contains.
///
/// Unlike `hashValue`, which Swift seeds randomly per process, a `StableDigest` for a given value
/// is the same number in every process, on every platform and on every architecture. Geometry
/// nodes are identified by their digest, so a model built twice — in two runs, on two machines —
/// produces the same node tree in the same canonical order.
///
/// This fixes the tree, not the mesh. Whether the exported file then comes out byte for byte the
/// same depends on the geometry kernel, which this doesn't touch, so it is not a promise made here.
///
/// 128 bits makes an accidental collision negligible for any realistic number of nodes: at 2^32
/// distinct nodes in one model the birthday probability is still below 2^-64.
internal struct StableDigest: Hashable, Sendable, Comparable, CustomStringConvertible {
    internal let low: UInt64
    internal let high: UInt64

    internal init(low: UInt64, high: UInt64) {
        self.low = low
        self.high = high
    }

    /// Computes the digest of a single value.
    internal init(_ value: some StableHashable) {
        var hasher = StableHasher()
        hasher.combine(value)
        self = hasher.finalize()
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.high == rhs.high ? lhs.low < rhs.low : lhs.high < rhs.high
    }

    var description: String {
        String(format: "%016llx%016llx", high, low)
    }
}

extension StableDigest: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(word: low)
        hasher.combine(word: high)
    }
}

extension StableDigest: Codable {
    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard text.count == 32,
              let high = UInt64(text.prefix(16), radix: 16),
              let low = UInt64(text.suffix(16), radix: 16)
        else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(), debugDescription: "Malformed digest \"\(text)\""
            )
        }
        self.init(low: low, high: high)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// A value whose content can be folded into a ``StableDigest``.
///
/// Conformers must describe themselves to the hasher in a way that depends only on their content:
/// no `hashValue`, no `Hasher`, no pointer identity, no iteration order that varies between runs.
internal protocol StableHashable {
    func stableHash(into hasher: inout StableHasher)
}

/// A fixed-seed, structurally-defined hash function producing a ``StableDigest``.
///
/// This is SipHash-2-4 in its 128-bit output mode, with a key baked into the source. SipHash was
/// chosen over a simpler construction such as FNV-1a because node identity now rests entirely on
/// the digest — `==` compares digests and nothing else — so the avalanche quality of the mixing
/// function is what bounds the collision risk.
///
/// Everything enters the hasher as explicit little-endian 64-bit words, so the result does not
/// depend on the host's endianness or on the width of `Int`.
internal struct StableHasher {
    // An arbitrary but permanently fixed key. Changing it changes every digest, and with them the
    // canonical child order of every union, so don't.
    private static let key0: UInt64 = 0x4361_646f_7661_2d31 // "Cadova-1"
    private static let key1: UInt64 = 0x4e6f_6465_4964_656e // "NodeIden"

    private var v0: UInt64
    private var v1: UInt64
    private var v2: UInt64
    private var v3: UInt64

    // Bytes accepted since the last complete 8-byte block, packed little-endian.
    private var tail: UInt64 = 0
    private var tailCount: Int = 0
    private var byteCount: Int = 0

    internal init() {
        self.init(key0: Self.key0, key1: Self.key1)
    }

    /// Seeds the hasher with an explicit key.
    ///
    /// This exists so the construction can be checked against the published SipHash-2-4 reference
    /// vectors, which are stated for a key of `000102…0f`. Every digest Cadova itself computes goes
    /// through `init()` and the fixed key above, so the tested path is the shipping one.
    internal init(key0: UInt64, key1: UInt64) {
        v0 = key0 ^ 0x736f_6d65_7073_6575
        v1 = key1 ^ 0x646f_7261_6e64_6f6d ^ 0xee
        v2 = key0 ^ 0x6c79_6765_6e65_7261
        v3 = key1 ^ 0x7465_6462_7974_6573
    }

    @inline(__always)
    private static func rotateLeft(_ value: UInt64, _ amount: UInt64) -> UInt64 {
        (value &<< amount) | (value &>> (64 - amount))
    }

    @inline(__always)
    private mutating func round() {
        v0 = v0 &+ v1; v1 = Self.rotateLeft(v1, 13); v1 ^= v0; v0 = Self.rotateLeft(v0, 32)
        v2 = v2 &+ v3; v3 = Self.rotateLeft(v3, 16); v3 ^= v2
        v0 = v0 &+ v3; v3 = Self.rotateLeft(v3, 21); v3 ^= v0
        v2 = v2 &+ v1; v1 = Self.rotateLeft(v1, 17); v1 ^= v2; v2 = Self.rotateLeft(v2, 32)
    }

    @inline(__always)
    private mutating func absorb(_ block: UInt64) {
        v3 ^= block
        round()
        round()
        v0 ^= block
    }

    /// Feeds one byte.
    @inline(__always)
    internal mutating func combine(byte: UInt8) {
        tail |= UInt64(byte) &<< (8 * UInt64(tailCount))
        tailCount += 1
        byteCount += 1
        if tailCount == 8 {
            absorb(tail)
            tail = 0
            tailCount = 0
        }
    }

    /// Feeds exactly eight bytes, the little-endian representation of `word`.
    @inline(__always)
    internal mutating func combine(word: UInt64) {
        if tailCount == 0 {
            byteCount += 8
            absorb(word)
        } else {
            var remaining = word
            for _ in 0..<8 {
                combine(byte: UInt8(truncatingIfNeeded: remaining))
                remaining &>>= 8
            }
        }
    }

    internal mutating func combine(bytes: some Sequence<UInt8>) {
        for byte in bytes {
            combine(byte: byte)
        }
    }

    internal mutating func combine(_ value: some StableHashable) {
        value.stableHash(into: &self)
    }

    // Concrete overloads for the leaf types that dominate a node's payload. They do the same work
    // as going through `StableHashable`, but without a protocol witness call per value — which an
    // unoptimized build can't see through, and node digests are computed in debug builds too.
    @inline(__always)
    internal mutating func combine(_ value: Double) {
        combine(word: Self.canonicalBitPattern(of: value))
    }

    @inline(__always)
    internal mutating func combine(_ value: Int) {
        combine(word: UInt64(bitPattern: Int64(value)))
    }

    /// See ``Double/stableHash(into:)`` for why `-0.0` and `NaN` are folded to fixed patterns.
    @inline(__always)
    internal static func canonicalBitPattern(of value: Double) -> UInt64 {
        if value.isNaN { 0x7fff_ffff_ffff_ffff } else if value == 0 { 0 } else { value.bitPattern }
    }

    /// Produces the digest. The hasher is consumed conceptually; reusing it after this point is
    /// not meaningful.
    internal func finalize() -> StableDigest {
        var copy = self
        let block = tail | (UInt64(byteCount & 0xff) &<< 56)

        copy.v3 ^= block
        copy.round()
        copy.round()
        copy.v0 ^= block

        copy.v2 ^= 0xee
        copy.round(); copy.round(); copy.round(); copy.round()
        let low = copy.v0 ^ copy.v1 ^ copy.v2 ^ copy.v3

        copy.v1 ^= 0xdd
        copy.round(); copy.round(); copy.round(); copy.round()
        let high = copy.v0 ^ copy.v1 ^ copy.v2 ^ copy.v3

        return StableDigest(low: low, high: high)
    }
}

// MARK: - Standard library conformances

extension UInt64: StableHashable {
    @inline(__always)
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(word: self)
    }
}

extension Int: StableHashable {
    @inline(__always)
    func stableHash(into hasher: inout StableHasher) {
        // Always 64 bits wide, so a 32-bit host agrees with a 64-bit one.
        hasher.combine(word: UInt64(bitPattern: Int64(self)))
    }
}

extension Double: StableHashable {
    /// Two doubles that are `==` must produce the same digest, and node equality must stay
    /// reflexive. Two values need canonicalizing for that:
    ///
    /// - `-0.0` and `+0.0` are `==` but have different bit patterns, so `-0.0` is folded in as
    ///   `+0.0`.
    /// - `NaN` is never `==` itself, and every NaN payload is a distinct bit pattern. All of them
    ///   are folded in as one canonical marker, which makes two nodes carrying a `NaN` dimension
    ///   equal to each other. That is deliberate: node identity describes *how the geometry was
    ///   spelled*, and a cache keyed on a value that is never equal to itself would grow without
    ///   bound while never hitting.
    @inline(__always)
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(word: StableHasher.canonicalBitPattern(of: self))
    }
}

extension Bool: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(byte: self ? 1 : 0)
    }
}

extension String: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        let bytes = Array(utf8)
        hasher.combine(word: UInt64(bytes.count))
        hasher.combine(bytes: bytes)
    }
}

extension Array: StableHashable where Element: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(word: UInt64(count))
        for element in self {
            hasher.combine(element)
        }
    }
}

extension Optional: StableHashable where Wrapped: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .none:
            hasher.combine(byte: 0)
        case .some(let wrapped):
            hasher.combine(byte: 1)
            hasher.combine(wrapped)
        }
    }
}
