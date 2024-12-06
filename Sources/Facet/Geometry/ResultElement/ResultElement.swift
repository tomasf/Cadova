//
//  File.swift
//  
//
//  Created by Tomas Wincent Franzén on 2024-09-27.
//

import Foundation

public protocol ResultElement {
    static func combine(elements: [Self], for operation: GeometryCombination) -> Self?
}

internal extension ResultElement {
    static func combine(anyElements elements: [any ResultElement], for operation: GeometryCombination) -> Self? {
        combine(elements: elements as! [Self], for: operation)
    }
}

internal typealias ResultElementsByType = [ObjectIdentifier: any ResultElement]

internal extension ResultElementsByType {
    init(combining elements: [Self], operation: GeometryCombination) {
        self = elements.reduce(into: [ObjectIdentifier: [any ResultElement]]()) {
            for (key, value) in $1 {
                $0[key, default: []].append(value)
            }
        }
        .compactMapValues {
            $0.count > 1 ? type(of: $0[0]).combine(anyElements: $0, for: operation) : $0[0]
        }
    }

    subscript<E: ResultElement>(_ type: E.Type) -> E? {
        get { self[ObjectIdentifier(type)] as? E }
        set { self[ObjectIdentifier(type)] = newValue }
    }

    func setting<E: ResultElement>(_ type: E.Type, to value: E?) -> Self {
        var dict = self
        dict[E.self] = value
        return dict
    }
}
