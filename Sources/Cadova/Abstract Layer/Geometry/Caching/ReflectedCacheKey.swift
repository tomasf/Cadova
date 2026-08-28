import Foundation

/// The cache key for a `CachedGeometry` conformer, derived by reflecting over its stored
/// properties. See `CachedGeometry` for how individual properties are classified.
internal struct ReflectedCacheKey: CacheKey {
    let typeName: String
    let fields: [AnyCacheKey]

    init<G: CachedGeometry>(reflecting geometry: G, in environment: EnvironmentValues, context: EvaluationContext) async throws {
        typeName = String(reflecting: G.self)

        var fields: [AnyCacheKey] = []
        // Sequential on purpose: Mirror.Child (a tuple containing `Any`) isn't Sendable, so this
        // can't cross into a concurrent task group the way `asyncMap` does.
        for child in Mirror(reflecting: geometry).children {
            fields.append(try await Self.fieldKey(for: child, in: environment, context: context))
        }
        self.fields = fields
    }

    private static func fieldKey(
        for child: Mirror.Child,
        in environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws -> AnyCacheKey {
        if let readable = child.value as? any _EnvironmentCacheKeyReadable {
            return readable.cacheKeyValue(in: environment)
        }
        if let geometry2D = child.value as? any Geometry<D2> {
            let built = try await context.buildResult(for: geometry2D, in: environment)
            return AnyCacheKey(built.node)
        }
        if let geometry3D = child.value as? any Geometry<D3> {
            let built = try await context.buildResult(for: geometry3D, in: environment)
            return AnyCacheKey(built.node)
        }
        // `Sendable` is a marker protocol and can't appear in a conditional cast's target type
        // (`as? any CacheKey` won't compile), so this checks the runtime-visible part of
        // `CacheKey` first, then restores `Sendable` with a forced cast — the same pattern
        // `AnyCacheKey`'s own `Decodable` conformance already relies on.
        if let hashableCodable = child.value as? any Hashable & Codable {
            let key = (hashableCodable as Any) as! any CacheKey
            return AnyCacheKey(key)
        }
        preconditionFailure(
            "CachedGeometry: stored property \(child.label.map { "'\($0)' " } ?? "")of type \(type(of: child.value)) can't participate in automatic cache-key derivation — it must be @Environment-wrapped (with a CacheKey-conforming value), a Geometry, or itself conform to CacheKey (Hashable & Sendable & Codable)."
        )
    }
}

/// Lets `ReflectedCacheKey` pull a resolved, frozen value out of an `@Environment`-wrapped stored
/// property without ever hashing/encoding the live wrapper itself (see `CachedGeometry` for why
/// that distinction matters).
internal protocol _EnvironmentCacheKeyReadable {
    func cacheKeyValue(in environment: EnvironmentValues) -> AnyCacheKey
}

extension Environment: _EnvironmentCacheKeyReadable where T: CacheKey {
    func cacheKeyValue(in environment: EnvironmentValues) -> AnyCacheKey {
        AnyCacheKey(getter(environment))
    }
}
