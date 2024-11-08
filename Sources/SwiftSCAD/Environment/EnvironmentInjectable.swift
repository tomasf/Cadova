import Foundation

internal protocol EnvironmentInjectable {
    func inject(environment: EnvironmentValues?)
}

fileprivate func inject(environment: EnvironmentValues?, into target: Any) {
    for (_, value) in Mirror(reflecting: target).children {
        (value as? any EnvironmentInjectable)?.inject(environment: environment)
    }
}

internal func whileInjecting<T>(environment: EnvironmentValues, into target: Any, actions: () -> T) -> T {
    inject(environment: environment, into: target)
    let result = actions()
    inject(environment: nil, into: target)
    return result
}
