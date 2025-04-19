import Foundation
import Manifold3D

public indirect enum GeometryExpression2D: GeometryExpression, Sendable {
    public typealias D = D2

    case empty
    case shape (PrimitiveShape)
    case boolean ([GeometryExpression2D], type: BooleanOperationType)
    case transform (GeometryExpression2D, transform: AffineTransform2D)
    case convexHull (GeometryExpression2D)
    case raw (CrossSection, source: GeometryExpression2D?, cacheKey: ExpressionKey)
    case offset (GeometryExpression2D, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int)
    case projection (GeometryExpression3D, type: Projection)

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

extension GeometryExpression2D {
    public var isEmpty: Bool {
        if case .empty = self { true } else { false }
    }

    public func evaluate(in context: EvaluationContext) async -> CrossSection {
        switch self {
        case .empty:
            .empty

        case .shape (let shape):
            shape.evaluate()

        case .boolean (let members, let type):
            await CrossSection.boolean(type.manifoldRepresentation, with: context.geometries(for: members))

        case .transform (let expression, let transform):
            await context.geometry(for: expression).transform(transform)

        case .convexHull (let expression):
            await context.geometry(for: expression).hull()

        case .offset (let expression, let amount, let joinStyle, let miterLimit, let segmentCount):
            await context.geometry(for: expression)
                .offset(amount: amount, joinType: joinStyle.manifoldRepresentation, miterLimit: miterLimit, circularSegments: segmentCount)

        case .projection (let expression, let projection):
            switch projection {
            case .full:
                await context.geometry(for: expression).projection()
            case .slice (let z):
                await context.geometry(for: expression).slice(at: z)
            }

        case .raw (let crossSection, _, _):
            crossSection
        }
    }
}

extension GeometryExpression2D.PrimitiveShape {
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

