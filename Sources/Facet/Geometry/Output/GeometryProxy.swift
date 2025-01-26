import Foundation

public struct GeometryProxy: @unchecked Sendable {
    private let outputProvider: (EnvironmentValues) -> (any OutputDataProvider, name: String?)

    internal init(_ geometry: any Geometry2D) {
        outputProvider = { environment in
            let output = geometry.evaluated(in: environment)
            return (
                output.primitive.isEmpty ?
                ThreeMFDataProvider(output: .init(primitive: .empty, elements: output.elements))
                : ThreeMFDataProvider(output: Output3D(primitive: output.primitive.extrude(height: 0.001), elements: output.elements)),
                
               // SVGDataProvider(output: output),
                output.elements[GeometryName.self]?.name
            )
        }
    }

    internal init(_ geometry: any Geometry3D) {
        outputProvider = { environment in
            let startTime = CFAbsoluteTimeGetCurrent()
            let output = geometry.evaluated(in: environment)
            let finishTime = CFAbsoluteTimeGetCurrent()

            let name = output.elements[GeometryName.self]?.name
            print(String(format: "Generated geometry %@ in %g seconds", name ?? "?", finishTime - startTime))

            return (
                ThreeMFDataProvider(output: output),
                name
            )
        }
    }

    internal func evaluated(in environment: EnvironmentValues) -> (any OutputDataProvider, name: String?) {
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
