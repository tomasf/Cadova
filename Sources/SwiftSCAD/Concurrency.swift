import Foundation

internal extension Collection where Self: Sendable, Element: Sendable {
    func concurrentForEach(_ body: @Sendable @escaping (Element) -> Void) {
        if #available(macOS 10.15, *) {
            let semaphore = DispatchSemaphore(value: 0)

            Task {
                await withTaskGroup(of: Void.self) { taskGroup in
                    for element in self {
                        taskGroup.addTask {
                            body(element)
                        }
                    }
                }
                semaphore.signal()
            }
            semaphore.wait()
        } else {
            forEach(body)
        }
    }
}
