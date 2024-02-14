import Foundation

public struct Environment {
    private let values: [ValueKey: Any]

    public init() {
        self.init(values: [:])
    }

    init(values: [ValueKey: Any]) {
        self.values = values
    }

    public func setting(_ newValues: [ValueKey: Any]) -> Environment {
        Environment(values: values.merging(newValues, uniquingKeysWith: { $1 }))
    }

    public func setting(key: ValueKey, value: Any?) -> Environment {
        var values = self.values
        values[key] = value
        return Environment(values: values)
    }

    subscript(key: ValueKey) -> Any? {
        values[key]
    }
}

public extension Environment {
    struct ValueKey: RawRepresentable, Hashable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
