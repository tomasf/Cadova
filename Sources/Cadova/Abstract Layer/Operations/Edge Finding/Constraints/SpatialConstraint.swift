import Foundation

internal enum SpatialConstraint: Sendable, Hashable, Codable {
    case withinBox(BoundingBox3D)
    case withinAxisRange(Axis3D, RangeBound)
    case onLine(Line3D, tolerance: Double)
    case onPlane(Plane, tolerance: Double)
    case nearPoint(Vector3D, radius: Double)
    case above(Plane)
    case below(Plane)

    private static let tolerance = 1e-6

    func matches(_ edge: FoundEdge) -> Bool {
        edge.vertices.allSatisfy { vertex in
            switch self {
            case .withinBox(let box):
                box.contains(vertex)
            case .withinAxisRange(let axis, let bound):
                bound.contains(vertex[axis])
            case .onLine(let line, let tolerance):
                line.distance(to: vertex) <= tolerance
            case .onPlane(let plane, let tolerance):
                abs(plane.distance(to: vertex)) <= tolerance
            case .nearPoint(let point, let radius):
                vertex.distance(to: point) <= radius
            case .above(let plane):
                plane.distance(to: vertex) >= -Self.tolerance
            case .below(let plane):
                plane.distance(to: vertex) <= Self.tolerance
            }
        }
    }
}
