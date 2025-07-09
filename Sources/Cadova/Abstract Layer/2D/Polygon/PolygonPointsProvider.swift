import Foundation

protocol PolygonPointsProvider: Sendable {
    func points(in environment: EnvironmentValues) -> [Vector2D]
}

extension [Vector2D]: PolygonPointsProvider {
    func points(in environment: EnvironmentValues) -> [Vector2D] {
        self
    }
}

extension BezierPath2D: PolygonPointsProvider {
    func points(in environment: EnvironmentValues) -> [Vector2D] {
        points(segmentation: environment.segmentation)
    }
}

internal struct TransformedPolygonPoints: PolygonPointsProvider {
    let innerProvider: any PolygonPointsProvider
    let transformation: @Sendable (Vector2D) -> Vector2D

    func points(in environment: EnvironmentValues) -> [Vector2D] {
        innerProvider.points(in: environment)
            .map(transformation)
    }
}

internal struct JoinedPolygonPoints: PolygonPointsProvider {
    let providers: [any PolygonPointsProvider]

    func points(in environment: EnvironmentValues) -> [Vector2D] {
        providers.flatMap { $0.points(in: environment) }
    }
}

internal struct ReversedPolygonPoints: PolygonPointsProvider {
    let innerProvider: any PolygonPointsProvider

    func points(in environment: EnvironmentValues) -> [Vector2D] {
        innerProvider.points(in: environment).reversed()
    }
}
