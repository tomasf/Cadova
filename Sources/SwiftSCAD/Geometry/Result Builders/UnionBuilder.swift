import Foundation

@resultBuilder public struct UnionBuilder2D {
    public static func buildExpression(_ geometry: any Geometry2D) -> [any Geometry2D] {
        [geometry]
    }

    public static func buildExpression<S>(_ geometry: S) -> [any Geometry2D] where S: Sequence, S.Element: Geometry2D {
        Array(geometry)
    }

    public static func buildExpression(_ void: Void) -> [any Geometry2D] {
        []
    }

    public static func buildBlock(_ children: [any Geometry2D]...) -> [any Geometry2D] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ child: [any Geometry2D]?) -> [any Geometry2D] {
        child ?? []
    }

    public static func buildEither(first child: [any Geometry2D]) -> [any Geometry2D] {
        child
    }

    public static func buildEither(second child: [any Geometry2D]) -> [any Geometry2D] {
        child
    }

    public static func buildArray(_ children: [[any Geometry2D]]) -> [any Geometry2D] {
        children.flatMap { $0 }
    }

    public static func buildFinalResult(_ children: [any Geometry2D]) -> any Geometry2D {
        if children.count == 1 {
            children[0]
        } else {
            Union2D(children: children)
        }
    }
}

@resultBuilder public struct UnionBuilder3D {
    public static func buildExpression(_ geometry: any Geometry3D) -> [any Geometry3D] {
        [geometry]
    }

    public static func buildExpression<S>(_ geometry: S) -> [any Geometry3D] where S: Sequence, S.Element: Geometry3D {
        Array(geometry)
    }

    public static func buildExpression(_ void: Void) -> [any Geometry3D] {
        []
    }

    public static func buildBlock(_ children: [any Geometry3D]...) -> [any Geometry3D] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ child: [any Geometry3D]?) -> [any Geometry3D] {
        child ?? []
    }

    public static func buildEither(first child: [any Geometry3D]) -> [any Geometry3D] {
        child
    }

    public static func buildEither(second child: [any Geometry3D]) -> [any Geometry3D] {
        child
    }

    public static func buildArray(_ children: [[any Geometry3D]]) -> [any Geometry3D] {
        children.flatMap { $0 }
    }

    public static func buildFinalResult(_ children: [any Geometry3D]) -> any Geometry3D {
        if children.count == 1 {
            children[0]
        } else {
            Union3D(children: children)
        }
    }
}
