import Foundation

internal extension EnvironmentValues {
    @TaskLocal static var current: EnvironmentValues? = nil

    func whileCurrent<T>(_ actions: () async -> T) async -> T {
        await Self.$current.withValue(self) {
            await actions()
        }
    }

    func whileCurrent<T>(_ actions: () -> T) -> T {
        Self.$current.withValue(self) {
            actions()
        }
    }
}
