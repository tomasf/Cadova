import Foundation

public struct GeometryProxy: @unchecked Sendable {
    private let outputProvider: (EnvironmentValues) -> (CodeFragment, name: String?, [any OutputFormat])

    internal init(_ geometry: any Geometry2D) {
        outputProvider = { environment in
            let output = geometry.declaringFacets().evaluated(in: environment)
            return (
                output.codeFragment,
                output.elements[GeometryName.self]?.name,
                output.elements[OutputFormatSet2D.self]?.formats ?? [.scad]
            )
        }
    }

    internal init(_ geometry: any Geometry3D) {
        outputProvider = { environment in
            let output = geometry.declaringFacets().evaluated(in: environment)
            return (
                output.codeFragment,
                output.elements[GeometryName.self]?.name,
                output.elements[OutputFormatSet3D.self]?.formats ?? [.scad]
            )
        }
    }

    internal func evaluated(in environment: EnvironmentValues) -> (CodeFragment, name: String?, [any OutputFormat]) {
        outputProvider(environment)
    }
}

@resultBuilder public struct GeometryProxyBuilder {
    public static func buildExpression(_ expression: (any Geometry2D)?) -> [GeometryProxy] {
        [expression].compactMap { $0 }.map(GeometryProxy.init)
    }

    public static func buildExpression(_ expression: any Geometry2D) -> [GeometryProxy] {
        [GeometryProxy(expression)]
    }

    public static func buildExpression<S>(_ geometry: S) -> [GeometryProxy] where S: Sequence, S.Element == any Geometry2D {
        Array(geometry).map(GeometryProxy.init)
    }


    public static func buildExpression(_ expression: (any Geometry3D)?) -> [GeometryProxy] {
        [expression].compactMap { $0 }.map(GeometryProxy.init)
    }

    public static func buildExpression(_ expression: any Geometry3D) -> [GeometryProxy] {
        [GeometryProxy(expression)]
    }

    public static func buildExpression<S>(_ geometry: S) -> [GeometryProxy] where S: Sequence, S.Element == any Geometry3D {
        Array(geometry).map(GeometryProxy.init)
    }


    public static func buildExpression(_ void: Void) -> [GeometryProxy] {
        []
    }

    public static func buildExpression(_ never: Never) -> [GeometryProxy] {}

    public static func buildBlock(_ children: [GeometryProxy]...) -> [GeometryProxy] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ children: [GeometryProxy]?) -> [GeometryProxy] {
        children ?? []
    }

    public static func buildEither(first child: [GeometryProxy]) -> [GeometryProxy] {
        child
    }

    public static func buildEither(second child: [GeometryProxy]) -> [GeometryProxy] {
        child
    }

    public static func buildArray(_ children: [[GeometryProxy]]) -> [GeometryProxy] {
        children.flatMap { $0 }
    }
}
