import Foundation

// This is a task-local flag to instruct the Model initializer. Calling Model() by itself should initiate model creation right away.
// Calling it within a Project content builder should prepare for creation but let Project initiate it. To do this, we set
// isCollectingModels to true before calling Model.
internal struct ModelContext: Sendable {
    let isCollectingModels: Bool
}

extension ModelContext {
    @TaskLocal static var current: ModelContext = .init(isCollectingModels: false)

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
