import Foundation

internal extension EnvironmentValues {
    @TaskLocal static var current: EnvironmentValues? = nil

    func whileCurrent<T>(_ actions: () async throws -> T) async rethrows -> T {
        try await Self.$current.withValue(self) {
            try await actions()
        }
    }

    func whileCurrent<T>(_ actions: () -> T) -> T {
        Self.$current.withValue(self) {
            actions()
        }
    }
}

internal struct PushEnvironment<D: Dimensionality>: Geometry {
    let body: D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await environment.whileCurrent {
            try await body.build(in: environment, context: context)
        }
    }
}

public extension Geometry {
    func pushingEnvironment() -> D.Geometry {
        PushEnvironment(body: self)
    }
}
