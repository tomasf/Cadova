import Foundation

@propertyWrapper public struct EnvironmentValue<T> {
    private let keyPath: KeyPath<Environment, T>
    private let value = MutableValue()

    public init(_ keyPath: KeyPath<Environment, T>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: T {
        guard let value = value.value else {
            logger.warning("EnvironmentValue was evaluated without its value being set.")
            return Environment.defaultEnvironment[keyPath: keyPath]
        }
        return value
    }
}

internal protocol EnvironmentUpdatable {
    func update(with environment: Environment)
}

extension EnvironmentValue: EnvironmentUpdatable {
    final private class MutableValue { var value: T? }

    func update(with environment: Environment) {
        value.value = environment[keyPath: keyPath]
    }
}

internal extension Environment {
    func inject(into target: Any) {
        for child in Mirror(reflecting: target).children {
            (child.value as? any EnvironmentUpdatable)?.update(with: self)
        }
    }
}
