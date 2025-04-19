import Foundation

public protocol ResultElement: Sendable {
    static func combine(elements: [Self]) -> Self?
}

internal extension ResultElement {
    static func combine(anyElements elements: [any ResultElement]) -> Self? {
        combine(elements: elements as! [Self])
    }
}

internal typealias ResultElementsByType = [ObjectIdentifier: any ResultElement]

internal extension ResultElementsByType {
    init(combining elements: [Self]) {
        self = elements.reduce(into: [ObjectIdentifier: [any ResultElement]]()) {
            for (key, value) in $1 {
                $0[key, default: []].append(value)
            }
        }
        .compactMapValues {
            $0.count > 1 ? type(of: $0[0]).combine(anyElements: $0) : $0[0]
        }
    }

    subscript<E: ResultElement>(_ type: E.Type) -> E? {
        get { self[ObjectIdentifier(type)] as? E }
        set { self[ObjectIdentifier(type)] = newValue }
    }

    func setting<E: ResultElement>(_ value: E?) -> Self {
        var dict = self
        dict[E.self] = value
        return dict
    }
}
