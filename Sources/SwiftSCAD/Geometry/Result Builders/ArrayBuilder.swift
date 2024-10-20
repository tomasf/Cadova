import Foundation

@resultBuilder public struct ArrayBuilder<Element> {
    public static func buildExpression(_ expression: (Element)?) -> [Element] {
        [expression].compactMap { $0 }
    }

    public static func buildExpression(_ expression: Element) -> [Element] {
        [expression]
    }

    public static func buildExpression<S>(_ geometry: S) -> [Element] where S: Sequence, S.Element == Element {
        Array(geometry)
    }

    public static func buildExpression(_ void: Void) -> [Element] {
        []
    }

    public static func buildExpression(_ never: Never) -> [Element] {}

    public static func buildBlock(_ children: [Element]...) -> [Element] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ children: [Element]?) -> [Element] {
        children ?? []
    }

    public static func buildEither(first child: [Element]) -> [Element] {
        child
    }

    public static func buildEither(second child: [Element]) -> [Element] {
        child
    }

    public static func buildArray(_ children: [[Element]]) -> [Element] {
        children.flatMap { $0 }
    }
}

public typealias GeometryBuilder3D = ArrayBuilder<any Geometry3D>
public typealias GeometryBuilder2D = ArrayBuilder<any Geometry2D>
