import Foundation

public typealias CacheKey = Sendable & Hashable & Codable

internal struct NodeCacheKey<Key: CacheKey, D: Dimensionality>: CacheKey {
    let base: Key
    let node: D.Node
}

internal struct IndexedCacheKey<Key: CacheKey>: CacheKey {
    let base: Key
    let index: Int
}

internal struct LabeledCacheKey: CacheKey {
    let operationName: String
    let parameters: [OpaqueKey]

    init(operationName: String, parameters: [any Hashable & Sendable & Codable]) {
        self.operationName = operationName
        self.parameters = parameters.map { OpaqueKey($0) }
    }
}
