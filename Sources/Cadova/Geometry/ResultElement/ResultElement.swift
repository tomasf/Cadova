import Foundation

public protocol ResultElement: Sendable {
    init()
    init(combining: [Self])
}

internal extension ResultElement {
    static func combine(anyElements elements: [any ResultElement]) -> Self? {
        Self(combining: elements as! [Self])
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

    subscript<E: ResultElement>(_ type: E.Type) -> E {
        get {
            if let match = self[ObjectIdentifier(type)] {
                return match as! E
            } else {
                return E()
            }
        }
        set { self[ObjectIdentifier(type)] = newValue }
    }

    func setting<E: ResultElement>(_ value: E) -> Self {
        var dict = self
        dict[E.self] = value
        return dict
    }
}
