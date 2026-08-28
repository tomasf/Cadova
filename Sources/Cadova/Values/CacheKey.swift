import Foundation

/// A value that can be used as a cache key for materialized geometry results.
///
/// Pass values conforming to `CacheKey` as the `parameters` to APIs like
/// `EdgeShape.custom(name:parameters:curve:)`, which use them together with a name to uniquely
/// identify and deduplicate cached results. Most basic value types (numbers, strings, and so on)
/// already satisfy this out of the box.
public typealias CacheKey = Sendable & Hashable & Codable

internal struct NodeCacheKey<Key: CacheKey, D: Dimensionality>: CacheKey {
    let base: Key
    let node: D.Node
}

internal struct LabeledCacheKey: CacheKey {
    let operationName: String
    let parameters: [AnyCacheKey]

    init(operationName: String, parameters: [any Hashable & Sendable & Codable]) {
        self.operationName = operationName
        self.parameters = parameters.map { AnyCacheKey($0) }
    }
}
