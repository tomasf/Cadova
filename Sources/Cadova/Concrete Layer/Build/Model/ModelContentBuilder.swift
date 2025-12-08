import Foundation

@resultBuilder public struct ModelContentBuilder {
    public static func buildExpression(_ geometry: any Geometry2D) -> [BuildDirective] {
        [BuildDirective(payload: .geometry2D(geometry))]
    }

    public static func buildExpression(_ geometry: any Geometry3D) -> [BuildDirective] {
        [BuildDirective(payload: .geometry3D(geometry))]
    }

    public static func buildExpression(_ metadata: Metadata) -> [BuildDirective] {
        [BuildDirective(payload: .options(ModelOptions(metadata)))]
    }

    public static func buildExpression(_ environment: Environment<@Sendable (inout EnvironmentValues) -> ()>) -> [BuildDirective] {
        [BuildDirective(payload: .environment(environment.getter(.init())))]
    }

    public static func buildExpression(_ void: Void) -> [BuildDirective] { [] }
    public static func buildExpression(_ never: Never) -> [BuildDirective] {}

    public static func buildBlock(_ children: [BuildDirective]...) -> [BuildDirective] {
        children.flatMap { $0 }
    }

    public static func buildOptional(_ children: [BuildDirective]?) -> [BuildDirective] {
        children ?? []
    }

    public static func buildEither(first child: [BuildDirective]) -> [BuildDirective] {
        child
    }

    public static func buildEither(second child: [BuildDirective]) -> [BuildDirective] {
        child
    }

    public static func buildArray(_ children: [[BuildDirective]]) -> [BuildDirective] {
        children.flatMap { $0 }
    }
}
