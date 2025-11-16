import Foundation

@resultBuilder public struct GeometryBuilder<D: Dimensionality> {
    public typealias G = any Geometry<D>

    public static func buildExpression(_ expression: G?) -> [G] {
        [expression].compactMap { $0 }
    }

    public static func buildExpression(_ expression: G) -> [G] {
        [expression]
    }

    public static func buildExpression<S: Sequence<G>>(_ geometry: S) -> [G] {
        Array(geometry)
    }

    public static func buildExpression(_ void: Void) -> [G] {
        []
    }

    public static func buildExpression(_ never: Never) -> [G] {}

    public static func buildBlock(_ children: [G]...) -> [G] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ children: [G]?) -> [G] {
        children ?? []
    }

    public static func buildEither(first child: [G]) -> [G] {
        child
    }

    public static func buildEither(second child: [G]) -> [G] {
        child
    }

    public static func buildArray(_ children: [[G]]) -> [G] {
        children.flatMap { $0 }
    }

    public static func buildFinalResult(_ components: [G]) -> G {
        if components.count == 1 {
            components[0]
        } else {
            Union(components)
        }
    }
}

public typealias SequenceBuilder<D: Dimensionality> = ArrayBuilder<D.Geometry>
