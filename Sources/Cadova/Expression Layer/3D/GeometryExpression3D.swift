import Foundation
import Manifold3D

public struct GeometryExpression3D: GeometryExpression, Sendable {
    public typealias D = D3

    internal let contents: Contents

    internal init(_ contents: Contents) {
        self.contents = contents
    }

    indirect enum Contents {
        case empty
        case shape (PrimitiveShape)
        case boolean ([GeometryExpression3D], type: BooleanOperationType)
        case transform (GeometryExpression3D, transform: AffineTransform3D)
        case convexHull (GeometryExpression3D)
        case materialized (cacheKey: OpaqueKey)
        case applyMaterial (GeometryExpression3D, Material)
        case extrusion (GeometryExpression2D, type: Extrusion)
        case lazyUnion ([GeometryExpression3D])
    }

    public enum PrimitiveShape: Hashable, Sendable, Codable {
        case box (size: Vector3D)
        case sphere (radius: Double, segmentCount: Int)
        case cylinder (bottomRadius: Double, topRadius: Double, height: Double, segmentCount: Int)
        case convexHull (points: [Vector3D])
        case mesh (MeshData)
    }

    public enum Extrusion: Hashable, Sendable, Codable {
        case linear (height: Double, twist: Angle, divisions: Int, scaleTop: Vector2D)
        case rotational (angle: Angle, segments: Int)

        var isEmpty: Bool {
            switch self {
            case .linear (let height, _, _, _): height <= 0
            case .rotational (let angle, _): angle <= 0°
            }
        }
    }
}

extension GeometryExpression3D {
    public var isEmpty: Bool {
        if case .empty = contents { true } else { false }
    }

    public func evaluate(in context: EvaluationContext) async -> ExpressionResult<D> {
        switch contents {
        case .empty:
            return .empty

        case .shape (let shape):
            return Result(original: shape.evaluate())

        case .boolean (let members, let booleanOperation):
            let results = await context.results(for: members)
            return Result(product: .boolean(booleanOperation.manifoldRepresentation, with: results.map(\.primitive)), results: results)

        case .transform (let expression, let transform):
            return await context.result(for: expression).modified { $0.transform(transform) }

        case .convexHull (let expression):
            return await context.result(for: expression).modified { $0.hull() }

        case .applyMaterial (let expression, let material):
            return await context.result(for: expression).applyingMaterial(material)

        case .materialized (_):
            preconditionFailure("Materialized geometry expressions are pre-cached and cannot be evaluated")

        case .extrusion (let expression, let extrusion):
            let result = await context.result(for: expression)
            return switch extrusion {
            case .linear (let height, let twist, let divisions, let scaleTop):
                Result(original: result.primitive.extrude(height: height, divisions: divisions, twist: twist.degrees, scaleTop: scaleTop))

            case .rotational (let angle, let segmentCount):
                Result(original: result.primitive.revolve(degrees: angle.degrees, circularSegments: segmentCount))
            }

        case .lazyUnion (let members):
            let results = await context.results(for: members)
            return Result(product: .init(composing: results.map(\.primitive)), results: results)
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

        case .mesh (let meshData):
            do {
                return try Manifold(meshData.meshGL())
            } catch ManifoldError.notManifold {
                logger.error("""
Mesh creation failed: The mesh is not manifold.

This means some edges or vertices are shared in a way that makes the shape ambiguous or invalid for solid geometry. 
Common causes include:
- Holes or missing faces
- Edges shared by more than two faces
- Non-contiguous face loops
- Duplicate or misordered vertices

Ensure that your mesh defines a closed, watertight surface where every edge is shared by exactly two faces, and all faces have consistent winding. Try visualizedForDebugging() to visualize the faces of a mesh without requiring it to be manifold.
""")
                return .empty
            } catch {
                logger.error("Mesh creation failed: \(error)")
                return .empty
            }
        }
    }
}
