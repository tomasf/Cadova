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
            preconditionFailure("All elements for one output element key must be of the same type")
        }
        return combine(elements: typedElements, operation: operation)
    }
}

extension Array: GeometryOutputElement {
    public static func combine(elements: [[Element]], operation: GeometryCombination) -> [Element]? {
        Array(elements.joined())
    }
}

internal typealias GeometryOutputElements = [GeometryOutputElementKey: any GeometryOutputElement]

public enum GeometryCombination {
    case union
    case intersection
    case difference
    case minkowskiSum
}

/// Represents a key for geometry output elements.
public struct GeometryOutputElementKey: RawRepresentable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

internal extension GeometryOutputElements {
    static func combine(_ elements: [GeometryOutputElements], operation: GeometryCombination) -> GeometryOutputElements {
        var result: GeometryOutputElements = [:]

        let valueArraysForKeys = elements.reduce(into: [GeometryOutputElementKey: [any GeometryOutputElement]]()) {
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
}
