import Foundation
import Testing
@testable import Cadova

struct GeometryExpressionSimplificationTests {
    let rectangle = GeometryExpression2D.shape(.rectangle(size: Vector2D(1, 2)))
    let box = GeometryExpression3D.shape(.box(size: Vector3D(1, 2, 3)))
    let zeroCircle = GeometryExpression2D.shape(.circle(radius: 0, segmentCount: 10))
    let zeroBox = GeometryExpression3D.shape(.box(size: Vector3D(1, -1, 3)))

    let emptyUnion2D = GeometryExpression2D.boolean([], type: .union)
    let emptyUnion3D = GeometryExpression3D.boolean([], type: .union)

    @Test func emptyUnion() {
        #expect(emptyUnion2D.simplified().isEmpty)
        #expect(emptyUnion3D.simplified().isEmpty)
    }

    @Test func singleUnion() {
        let singleUnion2D = GeometryExpression2D.boolean([rectangle], type: .union)
        #expect(singleUnion2D.simplified() == rectangle)

        let singleUnion3D = GeometryExpression3D.boolean([box], type: .union)
        #expect(singleUnion3D.simplified() == box)
    }

    @Test func emptyBaseDifference() {
        let emptyBase2D = GeometryExpression2D.boolean([.empty, rectangle], type: .difference)
        #expect(emptyBase2D.simplified().isEmpty)

        let nonEmptyBase2D = GeometryExpression2D.boolean([rectangle, .empty], type: .difference)
        #expect(nonEmptyBase2D.simplified() == rectangle)

        let emptyBase3D = GeometryExpression3D.boolean([.empty, box], type: .difference)
        #expect(emptyBase3D.simplified().isEmpty)

        let nonEmptyBase3D = GeometryExpression3D.boolean([box, .empty], type: .difference)
        #expect(nonEmptyBase3D.simplified() == box)
    }

    @Test func emptyChildrenDifference() {
        let emptyChildren2D = GeometryExpression2D.boolean([rectangle, .empty, .empty], type: .difference)
        #expect(emptyChildren2D.simplified() == rectangle)

        let emptyChildren3D = GeometryExpression3D.boolean([box, .empty, .empty], type: .difference)
        #expect(emptyChildren3D.simplified() == box)
    }

    @Test func zeroSizes() {
        #expect(zeroBox.simplified().isEmpty)
        #expect(zeroCircle.simplified().isEmpty)
    }

    @Test func zeroSizesInUnion() {
        let zeroUnion2D = GeometryExpression2D.boolean([zeroCircle, .empty], type: .union)
        #expect(zeroUnion2D.simplified().isEmpty)

        let zeroUnion3D = GeometryExpression3D.boolean([.empty, zeroBox], type: .union)
        #expect(zeroUnion3D.simplified().isEmpty)
    }

    @Test func emptyOperands() {
        let emptyOffset = GeometryExpression2D.offset(.empty, amount: 1.0, joinStyle: .miter, miterLimit: 4.0, segmentCount: 8)
        #expect(emptyOffset.simplified().isEmpty)

        let emptyTransform2D = GeometryExpression2D.transform(.empty, transform: .identity)
        #expect(emptyTransform2D.simplified().isEmpty)

        let emptyExtrusion = GeometryExpression3D.extrusion(.empty, type: .linear(height: 10, twist: 0°, divisions: 0, scaleTop: .zero))
        #expect(emptyExtrusion.simplified().isEmpty)

        let emptyTransform3D = GeometryExpression3D.transform(.empty, transform: .identity)
        #expect(emptyTransform3D.simplified().isEmpty)

        let emptyConvexHull = GeometryExpression3D.convexHull(.empty)
        #expect(emptyConvexHull.simplified().isEmpty)
    }

    @Test func nestedEmptyChildren() {
        let nestedUnion = GeometryExpression3D.boolean([
            .empty,
            emptyUnion3D,
            box
        ], type: .union)
        #expect(nestedUnion.simplified() == box)

        let nestedDifference = GeometryExpression3D.boolean([
            .empty,
            emptyUnion3D,
            box
        ], type: .difference)
        #expect(nestedDifference.simplified().isEmpty)

        let nestedIntersection = GeometryExpression3D.boolean([
            box,
            emptyUnion3D,
            .empty
        ], type: .intersection)
        #expect(nestedIntersection.simplified().isEmpty)
    }
}
