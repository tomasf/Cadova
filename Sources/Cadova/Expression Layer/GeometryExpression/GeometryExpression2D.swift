import Foundation
import Manifold3D

indirect enum GeometryExpression2D: GeometryExpression, Sendable {
    typealias D = D2

    case empty
    case shape (PrimitiveShape)
    case boolean ([GeometryExpression2D], type: BooleanOperationType)
    case transform (GeometryExpression2D, transform: AffineTransform2D)
    case convexHull (GeometryExpression2D)
    case raw (CrossSection)
    case offset (GeometryExpression2D, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int)
    case projection (GeometryExpression3D, type: Projection)

    enum PrimitiveShape: Hashable, Sendable, Codable {
        case rectangle (size: Vector2D)
        case circle (radius: Double, segmentCount: Int)
        case polygon (points: [Vector2D], fillRule: FillRule)
    }

    enum Projection: Hashable, Sendable, Codable {
        case full
        case slice (z: Double)
    }
}

extension GeometryExpression2D {
    var children: [any GeometryExpression] {
        switch self {
        case .boolean(let children, _): children
        case .transform(let body, _), .convexHull(let body), .offset(let body, _, _, _, _): [body]
        case .projection(let body, _): [body]
        case .empty, .shape, .raw: []
        }
    }

    var isCacheable: Bool {
        switch self {
        case .empty, .shape: true
        case .raw: false
        default: children.allSatisfy(\.isCacheable)
        }
    }

    var isEmpty: Bool {
        if case .empty = self { true } else { false }
    }

    func evaluate(in context: EvaluationContext) async -> CrossSection {
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

        case .raw (let crossSection):
            crossSection
        }
    }
}

extension GeometryExpression2D.PrimitiveShape {
    func evaluate() -> CrossSection {
        switch self {
        case .rectangle (let size):
            CrossSection.square(size: size)
        case .circle (let radius, let segmentCount):
            CrossSection.circle(radius: radius, segmentCount: segmentCount)
        case .polygon (let points, let fillRule):
            CrossSection(polygons: [Manifold3D.Polygon(vertices: points)], fillRule: fillRule.primitive)
        }
    }
}
