import Foundation

/// Configuration options for model building and export.
public struct ModelOptions: Sendable, ExpressibleByArrayLiteral {
    private let items: [any ModelOptionItem]

    internal init(_ item: any ModelOptionItem) {
        self.items = [item]
    }

    internal init(_ options: [Self]) {
        self.items = options.flatMap(\.items)
    }

    internal subscript<T: ModelOptionItem>(_ type: T.Type) -> T {
        items.compactMap { $0 as? T }.reduce(.defaultValue, { $0.combined(with: $1) })
    }

    public init(arrayLiteral elements: Self...) {
        self.items = elements.flatMap(\.items)
    }
}

internal protocol ModelOptionItem: Sendable {
    static var defaultValue: Self { get }
    func combined(with other: Self) -> Self
}

internal struct ModelName: ModelOptionItem {
    let name: String?

    static let defaultValue = Self(name: nil)
    func combined(with other: ModelName) -> ModelName { other }
}
