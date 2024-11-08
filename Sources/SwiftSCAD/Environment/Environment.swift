import Foundation

@propertyWrapper public struct Environment<T> {
    private let keyPath: KeyPath<EnvironmentValues, T>
    private let value = MutableValue()

    public init() where T == EnvironmentValues {
        self.init(\.self)
    }

    public init(_ keyPath: KeyPath<EnvironmentValues, T>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: T {
        guard let value = value.value else {
            logger.error("@Environment value was accessed outside of a Shape's body, which is unsupported. Returning a default value.")
            return EnvironmentValues.defaultEnvironment[keyPath: keyPath]
        }
        return value
    }
}

extension Environment: EnvironmentInjectable {
    final private class MutableValue { var value: T? }

    func inject(environment: EnvironmentValues?) {
        value.value = environment?[keyPath: keyPath]
    }
}
