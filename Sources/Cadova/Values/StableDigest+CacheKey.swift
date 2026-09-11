import Foundation

extension StableDigest {
    /// The digest of an arbitrary cache key value.
    ///
    /// A cache key is only required to be `Hashable & Sendable & Codable`, so there are two paths:
    ///
    /// - Types Cadova knows about conform to ``StableHashable`` and describe themselves directly.
    ///   That is the path everything on the hot path takes, and it stays O(1) for values that
    ///   already carry a digest, such as a geometry node.
    /// - Anything else — a user's own key type — is folded in through its `Codable` representation,
    ///   encoded with sorted keys so the byte stream doesn't depend on dictionary ordering.
    ///
    /// The value's dynamic type name goes in either way, so two different types holding the same
    /// payload stay distinct.
    ///
    /// Two caveats apply to the `Codable` path. A `Set`, or a `Dictionary` whose keys are not
    /// `String`, encodes as an array in its per-process iteration order, so a key type holding one is
    /// not stable across runs; conform such a type to ``StableHashable``, or sort the members before
    /// encoding. And `StableHashable` folds `-0.0` into `+0.0` while JSON keeps the two apart, so a
    /// key holding `-0.0` digests differently from one holding `+0.0` even though they compare equal.
    /// That costs a duplicate cache entry, never a wrong hit.
    internal init<T: Hashable & Sendable & Codable>(cacheKeyContent item: T) {
        var hasher = StableHasher()
        let dynamicType = type(of: item as Any)
        hasher.combine(_mangledTypeName(dynamicType) ?? String(reflecting: dynamicType))

        if let stable = item as? any StableHashable {
            hasher.combine(stable)
        } else {
            do {
                // Wrapped in an array so that a scalar key doesn't depend on top-level fragment
                // support.
                hasher.combine(bytes: try Self.cacheKeyEncoder.encode([item]))
            } catch {
                // Deriving a digest from something else here would be worse than stopping.
                // `AnyCacheKey` compares by digest alone, so two distinct keys that both failed to
                // encode and happened to describe alike would compare equal and share one cache
                // entry, handing back the wrong geometry.
                preconditionFailure(
                    "Cache key of type \(String(reflecting: dynamicType)) failed to encode: \(error)"
                )
            }
        }

        self = hasher.finalize()
    }

    private static let cacheKeyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Without this a key holding an infinity or a NaN throws, which is the one encode failure a
        // caller can reach with an ordinary `Double`. Fixed spellings keep all NaNs alike, matching
        // what the `StableHashable` path does.
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "nan"
        )
        return encoder
    }()
}

extension LabeledCacheKey: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(operationName)
        hasher.combine(parameters)
    }
}

extension NodeCacheKey: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(StableDigest(cacheKeyContent: base))
        hasher.combine(node)
    }
}

extension ReflectedCacheKey: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(typeName)
        hasher.combine(fields)
    }
}
