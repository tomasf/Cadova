import Foundation

internal struct OutputContext {
    let directory: URL?
    let environmentValues: EnvironmentValues?
}

extension OutputContext {
    private static let threadLocalValueKey = "Cadova.OutputContextStack"

    private static var threadLocalStack: [OutputContext] {
        get { Thread.current.threadDictionary[threadLocalValueKey] as? [OutputContext] ?? [] }
        set { Thread.current.threadDictionary[threadLocalValueKey] = newValue }
    }

    static var current: OutputContext? {
        threadLocalStack.last
    }

    static func push(_ context: OutputContext) {
        threadLocalStack.append(context)
    }

    static func pop() {
        threadLocalStack.removeLast()
    }

    func whileCurrent(_ actions: () -> Void) {
        Self.push(self)
        actions()
        Self.pop()
    }
}
