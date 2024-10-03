import Foundation

public struct AnyGeometry {
    private let elementsProvider: (Environment) -> ResultElementsByType

    internal init(_ geometry: any Geometry2D) {
        self.elementsProvider = geometry.elements(in:)
    }

    internal init(_ geometry: any Geometry3D) {
        self.elementsProvider = geometry.elements(in:)
    }

    internal func namedGeometry(in environment: Environment) -> NamedGeometry? {
        elementsProvider(environment)[NamedGeometry.self]
    }
}

@resultBuilder public struct AnyGeometryBuilder {
    public static func buildExpression(_ expression: (any Geometry2D)?) -> [AnyGeometry] {
        [expression].compactMap { $0 }.map(AnyGeometry.init)
    }

    public static func buildExpression(_ expression: any Geometry2D) -> [AnyGeometry] {
        [AnyGeometry(expression)]
    }

    public static func buildExpression<S>(_ geometry: S) -> [AnyGeometry] where S: Sequence, S.Element == any Geometry2D {
        Array(geometry).map(AnyGeometry.init)
    }


    public static func buildExpression(_ expression: (any Geometry3D)?) -> [AnyGeometry] {
        [expression].compactMap { $0 }.map(AnyGeometry.init)
    }

    public static func buildExpression(_ expression: any Geometry3D) -> [AnyGeometry] {
        [AnyGeometry(expression)]
    }

    public static func buildExpression<S>(_ geometry: S) -> [AnyGeometry] where S: Sequence, S.Element == any Geometry3D {
        Array(geometry).map(AnyGeometry.init)
    }


    public static func buildExpression(_ void: Void) -> [AnyGeometry] {
        []
    }

    public static func buildExpression(_ never: Never) -> [AnyGeometry] {}

    public static func buildBlock(_ children: [AnyGeometry]...) -> [AnyGeometry] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ children: [AnyGeometry]?) -> [AnyGeometry] {
        children ?? []
    }

    public static func buildEither(first child: [AnyGeometry]) -> [AnyGeometry] {
        child
    }

    public static func buildEither(second child: [AnyGeometry]) -> [AnyGeometry] {
        child
    }

    public static func buildArray(_ children: [[AnyGeometry]]) -> [AnyGeometry] {
        children.flatMap { $0 }
    }
}
