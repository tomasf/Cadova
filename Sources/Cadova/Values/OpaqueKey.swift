import Foundation

public struct OpaqueKey: Hashable, Sendable, Codable, CustomDebugStringConvertible {
    private let content: any Hashable & Sendable & Codable

    internal init<T: Hashable & Sendable & Codable>(_ item: T) {
        content = item
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(content)
    }

    public static func == (left: Self, right: Self) -> Bool {
        func compare<T: Equatable, U: Equatable>(lhs: T, rhs: U) -> Bool {
            if let rhsAsT = rhs as? T, lhs == rhsAsT {
                return true
            } else if let lhsAsU = lhs as? U, lhsAsU == rhs {
                return true
            } else {
                return false
            }
        }
        return compare(lhs: left.content, rhs: right.content)
    }

    public var debugDescription: String {
        String(describing: content)
    }
}

extension OpaqueKey {
    private enum CodingKeys: CodingKey {
        case type
        case value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let mangledType = _mangledTypeName(type(of: content))
        try container.encode(mangledType, forKey: .type)
        try container.encode(content, forKey: .value)

        guard let mangledType, _typeByName(mangledType) != nil else {
            logger.error("Encoding a mangled type name that can't be interpreted: \(mangledType ?? "nil")")
            return
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .type)

        guard let type = _typeByName(typeName) as? any Decodable.Type else {
            fatalError("Failed to interpret mangled type \(typeName)")
        }
        guard let wrapper = try container.decode(type, forKey: .value) as? any Hashable & Codable else {
            fatalError("Failed to cast wrapped value")
        }
        self.content = (wrapper as Any) as! any CacheKey
    }
}
