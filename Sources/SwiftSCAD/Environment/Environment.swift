import Foundation

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
