import Foundation

protocol PolygonPointsProvider {
    func points(in environment: Environment) -> [Vector2D]
}

extension [Vector2D]: PolygonPointsProvider {
    func points(in environment: Environment) -> [Vector2D] {
        self
    }
}

extension BezierPath: PolygonPointsProvider {
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
