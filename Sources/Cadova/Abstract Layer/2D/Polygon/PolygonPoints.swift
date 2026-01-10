import Foundation

internal indirect enum PolygonPoints: Sendable, Hashable, Codable {
    case literal ([Vector2D])
    case curve (OpaqueParametricCurve<Vector2D>)
    case transformed (PolygonPoints, Transform2D)
    case concatenated ([PolygonPoints])
    case reversed (PolygonPoints)

    func points(with segmentation: Segmentation) -> [Vector2D] {
        switch self {
        case .literal (let array): array
        case .curve (let curve): curve.curve.points(segmentation: segmentation)
        case .transformed (let polygonPoints, let transform):
            polygonPoints.points(with: segmentation)
                .map { transform.apply(to: $0) }
        case .concatenated (let members):
            members.flatMap { $0.points(with: segmentation) }
        case .reversed (let inner):
            inner.points(with: segmentation).reversed()
        }
    }
}
