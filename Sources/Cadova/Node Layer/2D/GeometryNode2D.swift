import Foundation
import Manifold3D

public struct GeometryNode2D: GeometryNode, Sendable {
    public typealias D = D2

    internal let contents: Contents

    internal init(_ contents: Contents) {
        self.contents = contents
    }

    internal indirect enum Contents {
        case empty
        case shape (PrimitiveShape)
        case boolean ([GeometryNode2D], type: BooleanOperationType)
        case transform (GeometryNode2D, transform: AffineTransform2D)
        case convexHull (GeometryNode2D)
        case materialized (cacheKey: OpaqueKey)
        case offset (GeometryNode2D, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int)
        case projection (GeometryNode3D, type: Projection)
    }

    public enum PrimitiveShape: Hashable, Sendable, Codable {
        case rectangle (size: Vector2D)
        case circle (radius: Double, segmentCount: Int)
        case polygon (points: [Vector2D], fillRule: FillRule)
    }

    public enum Projection: Hashable, Sendable, Codable {
        case full
        case slice (z: Double)
    }
}

public extension GeometryNode2D {
    var isEmpty: Bool {
        if case .empty = contents { true } else { false }
    }

    func evaluate(in context: EvaluationContext) async -> Self.Result {
        Result(await evaluate(in: context))
    }

    func evaluate(in context: EvaluationContext) async -> CrossSection {
        switch contents {
        case .empty: .empty

        case .shape (let shape):
            shape.evaluate()

        case .boolean (let members, let type):
            await CrossSection.boolean(type.manifoldRepresentation, with: context.results(for: members).map(\.concrete))

        case .transform (let expression, let transform):
            await context.result(for: expression).concrete.transform(transform)

        case .convexHull (let expression):
            await context.result(for: expression).concrete.hull()

        case .offset (let expression, let amount, let joinStyle, let miterLimit, let segmentCount):
            await context.result(for: expression).concrete
                .offset(amount: amount, joinType: joinStyle.manifoldRepresentation, miterLimit: miterLimit, circularSegments: segmentCount)

        case .projection (let expression, let projection):
            switch projection {
            case .full:
                await context.result(for: expression).concrete.projection()
            case .slice (let z):
                await context.result(for: expression).concrete.slice(at: z)
            }

        case .materialized (_):
            preconditionFailure("Materialized geometry expressions are pre-cached and cannot be evaluated")
        }
    }

}

extension GeometryNode2D.PrimitiveShape {
    func evaluate() -> CrossSection {
        switch self {
        case .rectangle (let size):
            guard size.x > 0, size.y > 0 else { return .empty }
            return CrossSection.square(size: size)

        case .circle (let radius, let segmentCount):
            guard radius >= 0 else { return .empty }
            return CrossSection.circle(radius: radius, segmentCount: segmentCount)

        case .polygon (let points, let fillRule):
            guard points.count >= 3 else { return .empty }
            return CrossSection(polygons: [Manifold3D.Polygon(vertices: points)], fillRule: fillRule.manifoldRepresentation)
        }
    }
}

