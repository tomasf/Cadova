import Foundation
import Manifold3D

public indirect enum GeometryExpression3D: GeometryExpression, Sendable {
    public typealias D = D3

    case empty
    case shape (PrimitiveShape)
    case boolean ([GeometryExpression3D], type: BooleanOperationType)
    case transform (GeometryExpression3D, transform: AffineTransform3D)
    case convexHull (GeometryExpression3D)
    case raw (Manifold, source: GeometryExpression3D?, cacheKey: ExpressionKey)
    case extrusion (GeometryExpression2D, type: Extrusion)
    #warning("get rid of this? hmm, maybe not")
    case material (GeometryExpression3D, material: Material)

    public enum PrimitiveShape: Hashable, Sendable, Codable {
        case box (size: Vector3D)
        case sphere (radius: Double, segmentCount: Int)
        case cylinder (bottomRadius: Double, topRadius: Double, height: Double, segmentCount: Int)
        case convexHull (points: [Vector3D])
        #warning("This should use something better than Polyhedron")
        case polyhedron (Polyhedron)
    }

    public enum Extrusion: Hashable, Sendable, Codable {
        case linear (height: Double, twist: Angle, divisions: Int, scaleTop: Vector2D)
        case rotational (angle: Angle, segments: Int)
    }
}

extension GeometryExpression3D {
    public var isEmpty: Bool {
        if case .empty = self { true } else { false }
    }

    public func evaluate(in context: EvaluationContext) async -> Manifold {
        switch self {
        case .empty:
            return .empty

        case .shape (let shape):
            return shape.evaluate()

        case .boolean (let members, let booleanOperation):
            return await .boolean(booleanOperation.manifoldRepresentation, with: context.geometries(for: members))

        case .transform (let expression, let transform):
            return await context.geometry(for: expression).transform(transform)

        case .convexHull (let expression):
            return await context.geometry(for: expression).hull()

        case .material (let expression, let material):
            let geometry = await context.geometry(for: expression).asOriginal()
            guard let originalID = geometry.originalID else {
                preconditionFailure("Original geometry should always have an ID")
            }
            await context.assign(material, to: originalID)
            return geometry

        case .extrusion (let expression, let extrusion):
            let geometry = await context.geometry(for: expression)
            return switch extrusion {
            case .linear (let height, let twist, let divisions, let scaleTop):
                geometry.extrude(height: height, divisions: divisions, twist: twist.degrees, scaleTop: scaleTop)

            case .rotational (let angle, let segmentCount):
                geometry.revolve(degrees: angle.degrees, circularSegments: segmentCount)
            }

        case .raw (let manifold, _, _):
            return manifold
        }
    }
}

extension GeometryExpression3D.PrimitiveShape {
    func evaluate() -> Manifold {
        switch self {
        case .box (let size):
            guard size.x > 0, size.y > 0, size.z > 0 else { return .empty }
            return Manifold.cube(size: size)

        case .sphere (let radius, let segmentCount):
            guard radius >= 0 else { return .empty }
            return Manifold.sphere(radius: radius, segmentCount: segmentCount)

        case .cylinder (let bottomRadius, let topRadius, let height, let segmentCount):
            guard height >= 0, (bottomRadius >= 0 || topRadius >= 0) else { return .empty }
            return Manifold.cylinder(height: height, bottomRadius: bottomRadius, topRadius: topRadius, segmentCount: segmentCount)

        case .convexHull (let points):
            guard points.count >= 4 else { return .empty }
            return Manifold.hull(points)

        case .polyhedron (let polyhedron):
            do {
                return try Manifold(polyhedron.meshGL())
            } catch {
                logger.error("Polyhedron mesh creation failed: \(error)")
                return .empty
            }
        }
    }
}
