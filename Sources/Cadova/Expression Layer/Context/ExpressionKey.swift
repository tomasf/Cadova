import Foundation

public struct ExpressionKey: CacheKey, CustomDebugStringConvertible {
    private let wrapper: any ExpressionKeyValue

    internal init<T: Hashable & Sendable & Codable>(_ object: T) {
        wrapper = WrappedValue(value: object)
    }

    public var debugDescription: String {
        wrapper.debugDescription
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrapper)
    }

    public static func ==(_ lhs: ExpressionKey, _ rhs: ExpressionKey) -> Bool {
        lhs.wrapper.isEqual(to: rhs.wrapper)
    }

    private struct WrappedValue<T: Hashable & Sendable & Codable>: ExpressionKeyValue {
        let value: T

        func unwrapped<U>() -> U? {
            value as? U
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(value)
        }

        func isEqual(to other: any ExpressionKeyValue) -> Bool {
            other.unwrapped() == value
        }

        var debugDescription: String {
            String(describing: value)
        }
    }
}

fileprivate protocol ExpressionKeyValue: CacheKey, CustomDebugStringConvertible {
    func unwrapped<U>() -> U?
    func isEqual(to other: any ExpressionKeyValue) -> Bool
}

extension ExpressionKey {
    enum CodingKeys: CodingKey {
        case type
        case value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_mangledTypeName(type(of: wrapper)), forKey: .type)
        try container.encode(wrapper, forKey: .value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .type)

        guard let type = _typeByName(typeName) as? any Codable.Type,
              let wrapper = try container.decode(type, forKey: .value) as? any ExpressionKeyValue
        else {
            fatalError("Failed to decode mangled type \(typeName)")
        }
        self.wrapper = wrapper
    }
}
