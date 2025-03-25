import Foundation

internal extension Collection where Self: Sendable, Element: Sendable {
    func concurrentForEach(_ body: @Sendable @escaping (Element) -> Void) {
        DispatchQueue.concurrentPerform(iterations: count) { i in
            let element = self[index(startIndex, offsetBy: i)]
            body(element)
        }
    }
}
