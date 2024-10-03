import Foundation

/// `Environment` provides a flexible container for environment-specific values influencing the rendering of geometries.
///
/// You can use `Environment` to customize settings and attributes that affect child geometries within SwiftSCAD. Modifiers allow for dynamic adjustments of the environment, which can be applied to geometries to affect their rendering or behavior.
public struct Environment: Sendable {
    private let values: [ValueKey: any Sendable]

    public init() {
        self.init(values: [:])
    }

    init(values: [ValueKey: any Sendable]) {
        self.values = values
    }

    /// Returns a new environment by adding new values to the current environment.
    ///
    /// - Parameter newValues: A dictionary of values to add to the environment.
    /// - Returns: A new `Environment` instance with the added values.
    public func setting(_ newValues: [ValueKey: any Sendable]) -> Environment {
        Environment(values: values.merging(newValues, uniquingKeysWith: { $1 }))
    }

    /// Returns a new environment with a specified value updated or added.
    ///
    /// - Parameters:
    ///   - key: The key for the value to update or add.
    ///   - value: The new value to set. If `nil`, the key is removed from the environment.
    /// - Returns: A new `Environment` instance with the updated values.
    public func setting(key: ValueKey, value: (any Sendable)?) -> Environment {
        var values = self.values
        values[key] = value
        return Environment(values: values)
    }

    /// Accesses the value associated with the specified key in the environment.
    ///
    /// - Parameter key: The key of the value to access.
    /// - Returns: The value associated with `key` if it exists; otherwise, `nil`.
    public subscript(key: ValueKey) -> (any Sendable)? {
        values[key]
    }
}

public extension Environment {
    /// Represents a key for environment values.
    struct ValueKey: RawRepresentable, Hashable, Sendable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.init(rawValue: rawValue)
        }
    }
}

public extension Environment {
    static var defaultEnvironment: Environment {
        Environment()
            .withFacets(.defaults)
    }
}
