import Foundation

protocol PolygonPointsProvider {
    func points(in environment: Environment) -> [Vector2D]
}

extension [Vector2D]: PolygonPointsProvider {
    func points(in environment: Environment) -> [Vector2D] {
        self
    }
}

extension BezierPath2D: PolygonPointsProvider {
    func points(in environment: Environment) -> [Vector2D] {
        points(facets: environment.facets)
    }
}

internal struct TransformedPolygonPoints: PolygonPointsProvider {
    let innerProvider: any PolygonPointsProvider
    let transformation: (Vector2D) -> Vector2D

    func points(in environment: Environment) -> [Vector2D] {
        innerProvider.points(in: environment)
            .map(transformation)
    }
}

internal struct JoinedPolygonPoints: PolygonPointsProvider {
    let providers: [any PolygonPointsProvider]

    func points(in environment: Environment) -> [Vector2D] {
        providers.flatMap { $0.points(in: environment) }
    }
}

internal struct ReversedPolygonPoints: PolygonPointsProvider {
    let innerProvider: any PolygonPointsProvider

    func points(in environment: Environment) -> [Vector2D] {
        innerProvider.points(in: environment).reversed()
    }
}

internal struct BezierPathRange: PolygonPointsProvider {
    let bezierPath: BezierPath2D
    let range: ClosedRange<BezierPath.Position>

    func points(in environment: Environment) -> [Vector2D] {
        bezierPath.points(in: range, facets: environment.facets)
    }
}
