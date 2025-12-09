import Foundation

internal indirect enum PolygonPoints: Sendable, Hashable, Codable {
    case literal ([Vector2D])
    case curve (OpaqueParametricCurve<Vector2D>)
    case transformed (PolygonPoints, Transform2D)
    case concatenated ([PolygonPoints])
    case reversed (PolygonPoints)

    func points(in environment: EnvironmentValues) -> [Vector2D] {
        switch self {
        case .literal (let array): array
        case .curve (let curve): curve.curve.points(segmentation: environment.scaledSegmentation)
        case .transformed (let polygonPoints, let transform):
            polygonPoints.points(in: environment)
                .map { transform.apply(to: $0) }
        case .concatenated (let members):
            members.flatMap { $0.points(in: environment) }
        case .reversed (let inner):
            inner.points(in: environment).reversed()
        }
    }
}
