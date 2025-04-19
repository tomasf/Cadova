import Foundation

internal struct OutputContext {
    let directory: URL?
    let environmentValues: EnvironmentValues?
    let evaluationContext: EvaluationContext?
}

extension OutputContext {
    @TaskLocal static var current: OutputContext? = nil

    func whileCurrent(_ actions: () -> Void) {
        Self.$current.withValue(self) {
            actions()
        }
    }
}
