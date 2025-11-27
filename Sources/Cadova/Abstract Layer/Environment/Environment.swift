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
@propertyWrapper public struct Environment<T: Sendable>: Sendable {
    internal let getter: @Sendable (EnvironmentValues) -> T

    public init() where T == EnvironmentValues {
        getter = { $0 }
    }

    public init(_ keyPath: KeyPath<EnvironmentValues, T>) {
        getter = { $0[keyPath: keyPath] }
    }

    public init(wrappedValue defaultValue: T, _ keyPath: KeyPath<EnvironmentValues, T?>) {
        getter = { $0[keyPath: keyPath] ?? defaultValue }
    }

    public var wrappedValue: T {
        getter(EnvironmentValues.current)
    }
}
