import Foundation
import Manifold3D

indirect enum GeometryExpression3D: Sendable {
    case empty
    case shape (PrimitiveShape)
    case boolean ([GeometryExpression3D], type: BooleanOperationType)
    case transform (GeometryExpression3D, transform: AffineTransform3D)
    case convexHull (GeometryExpression3D)
    case extrusion (GeometryExpression2D, kind: Extrusion)
    case material (GeometryExpression3D, material: Material)
    case raw (Manifold)

    enum PrimitiveShape: Hashable, Sendable, Codable {
        case box (size: Vector3D)
        case sphere (radius: Double, segmentCount: Int)
        case cylinder (bottomRadius: Double, topRadius: Double, height: Double, segmentCount: Int)
        case convexHull (points: [Vector3D])
        case polyhedron (Polyhedron)
    }

    enum Extrusion: Hashable, Sendable, Codable {
        case linear (height: Double, twist: Angle, divisions: Int, scaleTop: Vector2D)
        case rotational (angle: Angle, segments: Int)
    }
}

extension GeometryExpression3D {
    var isCacheable: Bool {
        switch self {
        case .empty, .shape:
            return true

        case .raw:
            return false

        case .boolean(let children, _):
            return children.allSatisfy(\.isCacheable)

        case .transform(let body, _), .convexHull(let body), .material(let body, _):
            return body.isCacheable

        case .extrusion(let body, _):
            return body.isCacheable
        }
    }

    func evaluate(in context: EvaluationContext) async -> Manifold {
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
            case .linear(let height, let twist, let divisions, let scaleTop):
                geometry.extrude(height: height, divisions: divisions, twist: twist.degrees, scaleTop: scaleTop)

            case .rotational(let angle, let segmentCount):
                geometry.revolve(degrees: angle.degrees, circularSegments: segmentCount)
            }

        case .raw (let manifold):
            return manifold
        }
    }
}

extension GeometryExpression3D.PrimitiveShape {
    func evaluate() -> Manifold {
        switch self {
        case .box (let size):
            return Manifold.cube(size: size)
        case .sphere (let radius, let segmentCount):
            return Manifold.sphere(radius: radius, segmentCount: segmentCount)
        case .cylinder (let bottomRadius, let topRadius, let height, let segmentCount):
            return Manifold.cylinder(height: height, bottomRadius: bottomRadius, topRadius: topRadius, segmentCount: segmentCount)
        case .convexHull (let points):
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

extension GeometryExpression3D {
    enum Kind: String, Codable, Hashable {
        case empty
        case shape
        case boolean
        case transform
        case convexHull
        case material
        case extrusion
        case raw
    }
}

extension GeometryExpression3D: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .empty:
            hasher.combine(Kind.empty)

        case .shape(let primitive):
            hasher.combine(Kind.shape)
            hasher.combine(primitive)

        case .boolean(let type, let children):
            hasher.combine(Kind.boolean)
            hasher.combine(type)
            hasher.combine(children)

        case .transform(let body, let transform):
            hasher.combine(Kind.transform)
            hasher.combine(body)
            hasher.combine(transform)

        case .convexHull(let body):
            hasher.combine(Kind.convexHull)
            hasher.combine(body)

        case .material(let body, let material):
            hasher.combine(Kind.material)
            hasher.combine(body)
            hasher.combine(material)

        case .extrusion(let body, let kind):
            hasher.combine(Kind.extrusion)
            hasher.combine(body)
            hasher.combine(kind)

        case .raw:
            hasher.combine(Kind.raw)
        }
    }

    static func == (lhs: GeometryExpression3D, rhs: GeometryExpression3D) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): return true
        case let (.shape(a), .shape(b)): return a == b
        case let (.boolean(ta, ca), .boolean(tb, cb)): return ta == tb && ca == cb
        case let (.transform(a1, t1), .transform(a2, t2)): return a1 == a2 && t1 == t2
        case let (.convexHull(a), .convexHull(b)): return a == b
        case let (.material(a1, m1), .material(a2, m2)): return a1 == a2 && m1 == m2
        case let (.extrusion(a1, k1), .extrusion(a2, k2)): return a1 == a2 && k1 == k2
        case (.raw, .raw): return false
        default: return false
        }
    }
}
