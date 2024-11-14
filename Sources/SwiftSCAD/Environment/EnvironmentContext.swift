import Foundation

private class EnvironmentContext {
    private static let key = "SwiftSCAD.EnvironmentContext"
    private var stack: [EnvironmentValues] = []

    static var threadLocal: EnvironmentContext {
        if let context = Thread.current.threadDictionary[Self.key] as? EnvironmentContext {
            return context
        } else {
            let context = EnvironmentContext()
            Thread.current.threadDictionary[Self.key] = context
            return context
        }
    }

    var topEnvironment: EnvironmentValues? {
        stack.last
    }

    func push(_ environment: EnvironmentValues) {
        stack.append(environment)
    }

    func pop() {
        precondition(!stack.isEmpty, "EnvironmentContext inconsistency")
        stack.removeLast()
    }
}

internal extension EnvironmentValues {
    static var current: EnvironmentValues? {
        EnvironmentContext.threadLocal.topEnvironment
    }

    func whileCurrent<T>(_ actions: () -> T) -> T {
        EnvironmentContext.threadLocal.push(self)
        let returnValue = actions()
        EnvironmentContext.threadLocal.pop()
        return returnValue
    }
}
