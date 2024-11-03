import Foundation

public struct AnyGeometry {
    private let elementsProvider: (Environment) -> ResultElementsByType
    private let codeFragmentProvider: (Environment) -> CodeFragment
    private let outputFormatReader: (ResultElementsByType) -> [any OutputFormat]

    internal init(_ geometry: any Geometry2D) {
        elementsProvider = geometry.elements(in:)
        codeFragmentProvider = geometry.codeFragment(in:)
        outputFormatReader = {
            $0[OutputFormatSet2D.self]?.formats ?? [.scad]
        }
    }

    internal init(_ geometry: any Geometry3D) {
        elementsProvider = geometry.elements(in:)
        codeFragmentProvider = geometry.codeFragment(in:)
        outputFormatReader = {
            $0[OutputFormatSet3D.self]?.formats ?? [.scad]
        }
    }

    internal func codeFragment(in environment: Environment) -> CodeFragment {
        codeFragmentProvider(environment)
    }

    internal func results(in environment: Environment) -> (name: String?, outputFormats: [any OutputFormat]) {
        let elements = elementsProvider(environment)
        let outputFormats = outputFormatReader(elements)
        let name = elements[GeometryName.self]?.name
        return (name, outputFormats)
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
