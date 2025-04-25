import Foundation

extension Geometry {
    func cached(as name: String, parameters cacheKeys: any CacheKey...) -> D.Geometry {
        CachedBoxedGeometry(key: NamedCacheKey(operationName: name, parameters: cacheKeys)) {
            self
        }
    }
}
