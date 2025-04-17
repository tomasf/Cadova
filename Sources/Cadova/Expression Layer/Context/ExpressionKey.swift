import Foundation

fileprivate protocol ExpressionKeyValue: Hashable, Sendable {
    func unwrapped<U>() -> U?
    func isEqual(to other: any ExpressionKeyValue) -> Bool
}

struct ExpressionKey: Hashable, Sendable {
    private let wrapper: any ExpressionKeyValue

    init<T: Hashable & Sendable>(_ object: T) {
        wrapper = WrappedValue(value: object)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(wrapper)
    }

    static func ==(_ lhs: ExpressionKey, _ rhs: ExpressionKey) -> Bool {
        lhs.wrapper.isEqual(to: rhs.wrapper)
    }

    private struct WrappedValue<T: Hashable & Sendable>: ExpressionKeyValue {
        let value: T

        func unwrapped<U>() -> U? {
            value as? U
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(value)
        }

        func isEqual(to other: any ExpressionKeyValue) -> Bool {
            other.unwrapped() == value
        }
    }
}
