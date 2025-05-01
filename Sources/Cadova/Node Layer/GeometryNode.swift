import Foundation
import Manifold3D

internal struct GeometryNode<D: Dimensionality>: Sendable {
    internal let contents: Contents

    internal init(_ contents: Contents) {
        self.contents = contents
    }

    internal indirect enum Contents: Sendable {
        case empty
        case boolean ([D.Node], type: BooleanOperationType)
        case transform (D.Node, transform: D.Transform)
        case convexHull (D.Node)
        case materialized (cacheKey: OpaqueKey)

        // 2D
        case shape2D (PrimitiveShape2D)
        case offset (D2.Node, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int)
        case projection (D3.Node, type: Projection)

        // 3D
        case shape3D (PrimitiveShape3D)
        case applyMaterial (D3.Node, Material)
        case extrusion (D2.Node, type: Extrusion)
        case lazyUnion ([D3.Node])
    }
}

extension GeometryNode {
    public enum Projection: Hashable, Sendable, Codable {
        case full
        case slice (z: Double)
    }
}

extension GeometryNode {
    public enum Extrusion: Hashable, Sendable, Codable {
        case linear (height: Double, twist: Angle = 0°, divisions: Int = 0, scaleTop: Vector2D = [1,1])
        case rotational (angle: Angle, segments: Int)

        var isEmpty: Bool {
            switch self {
            case .linear (let height, _, _, _): height <= 0
            case .rotational (let angle, _): angle <= 0°
            }
        }
    }
}


extension GeometryNode {
    typealias Result = EvaluationResult<D>

    var isEmpty: Bool {
        if case .empty = contents { true } else { false }
    }

    public func evaluate(in context: EvaluationContext) async -> Result {
        switch contents {
        case .empty:
            return .empty

        case .boolean (let members, let booleanOperation):
            let results = await context.results(for: members)
            return Result(product: .boolean(booleanOperation.manifoldRepresentation, with: results.map(\.concrete)), results: results)

        case .transform (let node, let transform):
            return await context.result(for: node).modified { $0.transform(transform as! D.Concrete.Transform) }

        case .convexHull (let node):
            return await context.result(for: node).modified { $0.hull() }

        case .materialized (_):
            preconditionFailure("Materialized geometry nodes are pre-cached and cannot be evaluated")

        case .shape2D (let shape):
            assert(D.self == D2.self, "Invalid dimensionality for node type")
            return Result(shape.evaluate() as! D.Concrete)

        case .offset (let node, let amount, let joinStyle, let miterLimit, let segmentCount):
            assert(D.self == D2.self, "Invalid dimensionality for node type")
            return Result(
                await context.result(for: node).concrete
                    .offset(amount: amount, joinType: joinStyle.manifoldRepresentation, miterLimit: miterLimit, circularSegments: segmentCount)
                as! D.Concrete
            )

        case .projection (let node, let projection):
            assert(D.self == D2.self, "Invalid dimensionality for node type")
            let crossSection: CrossSection

            switch projection {
            case .full:
                crossSection = await context.result(for: node).concrete.projection()
            case .slice (let z):
                crossSection = await context.result(for: node).concrete.slice(at: z)
            }

            return Result(crossSection as! D.Concrete)

        case .shape3D (let shape):
            assert(D.self == D3.self, "Invalid dimensionality for node type")
            return Result(shape.evaluate() as! D.Concrete)

        case .applyMaterial (let node, let material):
            assert(D.self == D3.self, "Invalid dimensionality for node type")
            return await context.result(for: node).applyingMaterial(material) as! Result

        case .extrusion (let node, let extrusion):
            assert(D.self == D3.self, "Invalid dimensionality for node type")
            let result = await context.result(for: node)
            let manifold: Manifold

            switch extrusion {
            case .linear (let height, let twist, let divisions, let scaleTop):
                manifold = result.concrete.extrude(height: height, divisions: divisions, twist: twist.degrees, scaleTop: scaleTop)

            case .rotational (let angle, let segmentCount):
                manifold = result.concrete.revolve(degrees: angle.degrees, circularSegments: segmentCount)
            }

            return Result(manifold as! D.Concrete)

        case .lazyUnion (let members):
            assert(D.self == D3.self, "Invalid dimensionality for node type")
            let results = await context.results(for: members)
            return Result(product: .init(composing: results.map(\.concrete) as! [D.Concrete]), results: results as! [Result])
        }
    }
}

public enum BooleanOperationType: String, Hashable, Sendable, Codable {
    case union
    case difference
    case intersection

    internal var manifoldRepresentation: Manifold3D.BooleanOperation {
        switch self {
        case .union: .union
        case .difference: .difference
        case .intersection: .intersection
        }
    }
}

