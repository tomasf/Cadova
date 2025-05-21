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
