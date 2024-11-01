import Foundation

@propertyWrapper public struct EnvironmentValue<T> {
    private let keyPath: KeyPath<Environment, T>
    private let value = MutableValue()

    public init(_ keyPath: KeyPath<Environment, T>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: T {
        guard let value = value.value else {
            logger.error("EnvironmentValue was accessed outside of a Shape's body, which is unsupported. Returning a default value.")
            return Environment.defaultEnvironment[keyPath: keyPath]
        }
        return value
    }
}

internal protocol EnvironmentUpdatable {
    func update(with environment: Environment?)
}

extension EnvironmentValue: EnvironmentUpdatable {
    final private class MutableValue { var value: T? }

    func update(with environment: Environment?) {
        value.value = environment?[keyPath: keyPath]
    }
}


fileprivate func inject(environment: Environment?, into target: Any) {
    for (_, value) in Mirror(reflecting: target).children {
        (value as? any EnvironmentUpdatable)?.update(with: environment)
    }
}

internal func whileInjecting<T>(environment: Environment, into target: Any, actions: () -> T) -> T {
    inject(environment: environment, into: target)
    let result = actions()
    inject(environment: nil, into: target)
    return result
}
