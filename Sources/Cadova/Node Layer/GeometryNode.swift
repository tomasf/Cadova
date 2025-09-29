import Foundation
import Manifold3D

internal struct GeometryNode<D: Dimensionality>: Sendable, Hashable {
    internal let contents: Contents
    internal let hash: Int

    internal init(_ contents: Contents) {
        self.contents = contents
        self.hash = contents.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
    }
    
    internal indirect enum Contents: Sendable {
        case empty
        case boolean ([D.Node], type: BooleanOperationType)
        case transform (D.Node, transform: D.Transform)
        case convexHull (D.Node)
        case refine (D.Node, edgeLength: Double)
        case simplify (D.Node, tolerance: Double)
        case materialized (cacheKey: OpaqueKey)

        // 2D
        case shape2D (PrimitiveShape2D)
        case offset (D2.Node, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int)
        case projection (D3.Node, type: Projection)

        // 3D
        case shape3D (PrimitiveShape3D)
        case applyMaterial (D3.Node, Material)
        case extrusion (D2.Node, type: Extrusion)
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

    public func evaluate(in context: EvaluationContext) async throws -> Result {
        switch contents {
        case .empty:
            return .empty

        case .boolean (let members, let booleanOperation):
            let results = try await context.results(for: members)
            return try Result(product: .boolean(booleanOperation.manifoldRepresentation, with: results.map(\.concrete)), results: results)

        case .transform (let node, let transform):
            return try await context.result(for: node).modified { $0.transform(transform as! D.Concrete.Transform) }

        case .convexHull (let node):
            return try await context.result(for: node).modified { $0.isEmpty ? .empty : $0.hull() }

        case .refine (let node, let edgeLength):
            return try await context.result(for: node).modified { $0.refine(edgeLength: edgeLength) }

        case .simplify(let node, let tolerance):
            return try await context.result(for: node).modified { $0.simplify(epsilon: tolerance) }

        case .materialized (_):
            preconditionFailure("Materialized geometry nodes are pre-cached and cannot be evaluated")

        default:
            switch D.self {
            case is D2.Type: return try await evaluate2D(in: context) as! Result
            case is D3.Type: return try await evaluate3D(in: context) as! Result
            default: fatalError()
            }
        }
    }

    private func evaluate2D(in context: EvaluationContext) async throws -> EvaluationResult<D2> {
        switch contents {
        case .shape2D (let shape):
            return try EvaluationResult(shape.evaluate())

        case .offset (let node, let amount, let joinStyle, let miterLimit, let segmentCount):
            return try EvaluationResult(
                try await context.result(for: node).concrete
                    .offset(amount: amount, joinType: joinStyle.manifoldRepresentation, miterLimit: miterLimit, circularSegments: segmentCount)
            )

        case .projection (let node, let projection):
            let crossSection: CrossSection = switch projection {
            case .full:           try await context.result(for: node).concrete.projection()
            case .slice (let z):  try await context.result(for: node).concrete.slice(at: z)
            }

            return try EvaluationResult(crossSection)

        default:
            preconditionFailure("Invalid dimensionality for node type")
        }
    }

    private func evaluate3D(in context: EvaluationContext) async throws -> EvaluationResult<D3> {
        switch contents {
        case .shape3D (let shape):
            return try EvaluationResult(shape.evaluate())

        case .applyMaterial (let node, let material):
            return try await context.result(for: node).applyingMaterial(material)

        case .extrusion (let node, let extrusion):
            let result = try await context.result(for: node)
            guard result.concrete.isEmpty == false else {
                return .empty
            }

            let manifold: Manifold
            switch extrusion {
            case .linear (let height, let twist, let divisions, let scaleTop):
                manifold = result.concrete.extrude(height: height, divisions: divisions, twist: twist.degrees, scaleTop: scaleTop)

            case .rotational (let angle, let segmentCount):
                let revolved: D3.Concrete = result.concrete.revolve(degrees: angle.degrees, circularSegments: segmentCount)
                manifold = revolved.status == nil ? revolved : .empty
            }

            return try EvaluationResult(manifold)
        default:
            preconditionFailure("Invalid dimensionality for node type")
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

