import Foundation

internal struct AnyCacheKey: Hashable, Sendable, Codable, CustomDebugStringConvertible {
    private let content: any Hashable & Sendable & Codable

    /// The wrapped value's stable content digest, including its type. Computed once, in `init`.
    internal let digest: StableDigest

    internal init<T: Hashable & Sendable & Codable>(_ item: T) {
        content = item
        digest = StableDigest(cacheKeyContent: item)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(digest)
    }

    // The digest folds in the wrapped value's dynamic type name, so two different types can't
    // collide the way a bare content comparison would have to guard against.
    static func == (left: Self, right: Self) -> Bool {
        left.digest == right.digest
    }

    var debugDescription: String {
        String(describing: content)
    }
}

extension AnyCacheKey: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(digest)
    }
}

extension AnyCacheKey {
    private enum CodingKeys: CodingKey {
        case type
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let mangledType = _mangledTypeName(type(of: content))
        try container.encode(mangledType, forKey: .type)
        try container.encode(content, forKey: .value)

        guard let mangledType, _typeByName(mangledType) != nil else {
            logger.error("Encoding a mangled type name that can't be interpreted: \(mangledType ?? "nil")")
            return
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .type)

        guard let type = _typeByName(typeName) as? any Decodable.Type else {
            fatalError("Failed to interpret mangled type \(typeName)")
        }
        guard let wrapper = try container.decode(type, forKey: .value) as? any Hashable & Codable else {
            fatalError("Failed to cast wrapped value")
        }
        let key = (wrapper as Any) as! any CacheKey
        self.init(key)
    }
}
