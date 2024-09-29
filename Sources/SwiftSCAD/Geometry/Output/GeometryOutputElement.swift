//
//  File.swift
//  
//
//  Created by Tomas Wincent Franzén on 2024-09-27.
//

import Foundation

public protocol GeometryOutputElement {
    static func combine(elements: [Self], for operation: GeometryCombination) -> Self?
}

internal extension GeometryOutputElement {
    static func combine(anyElements elements: [any GeometryOutputElement], for operation: GeometryCombination) -> Self? {
        combine(elements: elements as! [Self], for: operation)
    }
}

internal typealias OutputElementsByType = [ObjectIdentifier: any GeometryOutputElement]

internal extension OutputElementsByType {
    init(combining elements: [Self], operation: GeometryCombination) {
        self = elements.reduce(into: [ObjectIdentifier: [any GeometryOutputElement]]()) {
            for (key, value) in $1 {
                $0[key, default: []].append(value)
            }
        }
        .compactMapValues {
            $0.count > 1 ? type(of: $0[0]).combine(anyElements: $0, for: operation) : $0[0]
        }
    }

    subscript<E: GeometryOutputElement>(_ type: E.Type) -> E? {
        get { self[ObjectIdentifier(type)] as? E }
        set { self[ObjectIdentifier(type)] = newValue }
    }
}
