import Foundation

/// A property wrapper for reading values from `EnvironmentValues` within the context of a `Shape2D` or `Shape3D`.
///
/// Use `@Environment` to access values that are stored in the current environment, such as configuration or styling options.
/// It reads the specified key path from `EnvironmentValues`, or if none is specified, retrieves the entire `EnvironmentValues`.
///
/// - Important: Accessing an `@Environment` property outside the `body` property of a Shape is unsupported and returns a default value.
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
@propertyWrapper public struct Environment<T> {
    private let keyPath: KeyPath<EnvironmentValues, T>

    public init() where T == EnvironmentValues {
        self.init(\.self)
    }

    public init(_ keyPath: KeyPath<EnvironmentValues, T>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: T {
        guard let environment = EnvironmentValues.current else {
            logger.error("No active environment to read from. Perhaps you tried to access an @Environment property outside of a Shape's body, which is unsupported. Returning a default value.")
            return EnvironmentValues.defaultEnvironment[keyPath: keyPath]
        }

        return environment[keyPath: keyPath]
    }
}
