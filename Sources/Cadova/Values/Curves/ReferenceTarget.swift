import Foundation

public enum ReferenceTarget: Sendable, Hashable, Codable {
    case point (Vector3D)
    case line (D3.Line)
    case direction (Direction3D)
}

internal extension ReferenceTarget {
    func targetPoint(from plane: Plane) -> Vector3D {
        switch self {
        case let .point(p): p
        case let .line(line): plane.intersection(with: line) ?? line.closestPoint(to: plane.offset)
        case let .direction(dir): plane.offset + dir.unitVector
        }
    }
}
