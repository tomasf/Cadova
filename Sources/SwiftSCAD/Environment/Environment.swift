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

internal protocol EnvironmentUpdatable {
    func update(with environment: EnvironmentValues?)
}

extension Environment: EnvironmentUpdatable {
    final private class MutableValue { var value: T? }

    func update(with environment: EnvironmentValues?) {
        value.value = environment?[keyPath: keyPath]
    }
}


fileprivate func inject(environment: EnvironmentValues?, into target: Any) {
    for (_, value) in Mirror(reflecting: target).children {
        (value as? any EnvironmentUpdatable)?.update(with: environment)
    }
}

internal func whileInjecting<T>(environment: EnvironmentValues, into target: Any, actions: () -> T) -> T {
    inject(environment: environment, into: target)
    let result = actions()
    inject(environment: nil, into: target)
    return result
}
