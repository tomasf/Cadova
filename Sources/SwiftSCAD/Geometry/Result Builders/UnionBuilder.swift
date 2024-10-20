import Foundation

public typealias UnionBuilder2D = UnionBuilder<Vector2D>
public typealias UnionBuilder3D = UnionBuilder<Vector3D>

@resultBuilder public struct UnionBuilder<V: Vector> {
    public typealias Geometry = V.Geometry

    public static func buildExpression(_ geometry: Geometry) -> [Geometry] {
        [geometry]
    }

    public static func buildExpression<S>(_ geometry: S) -> [Geometry] where S: Sequence, S.Element == Geometry {
        Array(geometry)
    }

    public static func buildExpression(_ void: Void) -> [Geometry] {
        []
    }

    public static func buildExpression(_ never: Never) -> [Geometry] {}

    public static func buildBlock(_ children: [Geometry]...) -> [Geometry] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ child: [Geometry]?) -> [Geometry] {
        child ?? []
    }

    public static func buildEither(first child: [Geometry]) -> [Geometry] {
        child
    }

    public static func buildEither(second child: [Geometry]) -> [Geometry] {
        child
    }

    public static func buildArray(_ children: [[Geometry]]) -> [Geometry] {
        children.flatMap { $0 }
    }

    public static func buildFinalResult(_ children: [Geometry]) -> Geometry where Geometry == any Geometry2D {
        Union(children)
    }

    public static func buildFinalResult(_ children: [Geometry]) -> Geometry where Geometry == any Geometry3D {
        Union(children)
    }
}
