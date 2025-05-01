import Foundation

internal struct OutputContext: Sendable {
    let directory: URL?
    let environmentValues: EnvironmentValues?
    let evaluationContext: EvaluationContext?
    let options: ModelOptions
}

extension OutputContext {
    @TaskLocal static var current: OutputContext? = nil

    func whileCurrent<T>(_ actions: () -> T) -> T {
        Self.$current.withValue(self) {
            actions()
        }
    }

    func whileCurrent<T>(_ actions: () async -> T) async -> T {
        await Self.$current.withValue(self) {
            await actions()
        }
    }
}
