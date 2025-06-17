import Foundation

/// A property wrapper for reading values from the active environment.
///
/// Use `@Environment` to access values that are stored in the current environment, such as configuration or styling
/// options. It reads the specified key path from `EnvironmentValues`, or if none is specified, retrieves the
/// entire `EnvironmentValues`.
///
/// ## Usage
/// ```swift
/// @Environment(\.tolerance) var tolerance  // Reads a specific value from the environment
/// @Environment var environment             // Reads the entire environment
/// ```
///
/// - Parameters:
///   - keyPath: A key path to the value in `EnvironmentValues`, which determines the specific value to read.
///
@propertyWrapper public struct Environment<T>: Sendable {
    private let keyPath: KeyPath<EnvironmentValues, T>

    public init() where T == EnvironmentValues {
        self.init(\.self)
    }

    public init(_ keyPath: KeyPath<EnvironmentValues, T>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: T {
        EnvironmentValues.current[keyPath: keyPath]
    }
}
