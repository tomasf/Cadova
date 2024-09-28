//
//  File.swift
//  
//
//  Created by Tomas Wincent Franzén on 2024-09-27.
//

import Foundation

public protocol GeometryOutputElement {
    static func combine(elements: [Self], operation: GeometryCombination) -> Self?
}

internal extension GeometryOutputElement {
    static func combine(anyElements elements: [any GeometryOutputElement], operation: GeometryCombination) -> Self? {
        guard let typedElements = elements as? [Self] else {
            preconditionFailure("Internal error: output element type cast failed")
        }
        return combine(elements: typedElements, operation: operation)
    }
}

internal typealias GeometryOutputElements = [ObjectIdentifier: any GeometryOutputElement]

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}

internal extension GeometryOutputElements {
    static func combine(_ elements: [GeometryOutputElements], operation: GeometryCombination) -> GeometryOutputElements {
        var result: GeometryOutputElements = [:]

        let valueArraysForKeys = elements.reduce(into: [ObjectIdentifier: [any GeometryOutputElement]]()) {
            for (key, value) in $1 {
                $0[key, default: []].append(value)
            }
        }

        for (key, values) in valueArraysForKeys {
            if values.count > 1 {
                let type = type(of: values[0])
                result[key] = type.combine(anyElements: values, operation: operation)
            } else {
                result[key] = values[0]
            }
        }

        return result
    }

    subscript<E: GeometryOutputElement>(_ type: E.Type) -> E? {
        get {
            self[ObjectIdentifier(type)] as? E
        }
        set {
            self[ObjectIdentifier(type)] = newValue
        }
    }
}
