import Foundation

/// A result builder for composing geometry using a declarative syntax.
///
/// `GeometryBuilder` enables SwiftUI-style syntax for combining multiple geometries.
/// When multiple geometries are provided, they are automatically combined using a union operation.
///
/// You typically use this through the ``GeometryBuilder2D`` or ``GeometryBuilder3D`` typealiases,
/// or indirectly through ``Shape2D`` and ``Shape3D`` body properties.
///
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

/// A result builder that collects geometry into an array without combining them.
///
/// Unlike ``GeometryBuilder``, which unions multiple geometries into one, `SequenceBuilder`
/// preserves each geometry as a separate element. This is useful for operations that need
/// to process geometries individually.
///
public typealias SequenceBuilder<D: Dimensionality> = ArrayBuilder<D.Geometry>
