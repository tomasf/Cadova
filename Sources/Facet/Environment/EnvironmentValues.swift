import Foundation

/// `EnvironmentValues` provides a flexible container for environment-specific values influencing the rendering of geometries.
///
/// You can use `EnvironmentValues` to customize settings and attributes that affect child geometries within Facet. Modifiers allow for dynamic adjustments of the environment, which can be applied to geometries to affect their rendering or behavior.
public struct EnvironmentValues: Sendable {
    private let values: [Key: any Sendable]

    public init() {
        self.init(values: [:])
    }

    init(values: [Key: any Sendable]) {
        self.values = values
    }

    /// Returns a new environment by adding new values to the current environment.
    ///
    /// - Parameter newValues: A dictionary of values to add to the environment.
    /// - Returns: A new `EnvironmentValues` instance with the added values.
    public func setting(_ newValues: [Key: any Sendable]) -> EnvironmentValues {
        EnvironmentValues(values: values.merging(newValues, uniquingKeysWith: { $1 }))
    }

    /// Returns a new environment with a specified value updated or added.
    ///
    /// - Parameters:
    ///   - key: The key for the value to update or add.
    ///   - value: The new value to set. If `nil`, the key is removed from the environment.
    /// - Returns: A new `EnvironmentValues` instance with the updated values.
    public func setting(key: Key, value: (any Sendable)?) -> EnvironmentValues {
        var values = self.values
        values[key] = value
        return EnvironmentValues(values: values)
    }

    /// Accesses the value associated with the specified key in the environment.
    ///
    /// - Parameter key: The key of the value to access.
    /// - Returns: The value associated with `key` if it exists; otherwise, `nil`.
    public subscript(key: Key) -> (any Sendable)? {
        values[key]
    }
}

public extension EnvironmentValues {
    /// Represents a key for environment values.
    struct Key: RawRepresentable, Hashable, Sendable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.init(rawValue: rawValue)
        }
    }
}

public extension EnvironmentValues {
    static var defaultEnvironment: EnvironmentValues {
        EnvironmentValues()
            .withFacets(.defaults)
    }
}
