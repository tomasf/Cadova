import Foundation
import Testing
@testable import Cadova

struct GeometryNodeSimplificationTests {
    let rectangle = GeometryNode2D.shape(.rectangle(size: Vector2D(1, 2)))
    let box = GeometryNode3D.shape(.box(size: Vector3D(1, 2, 3)))
    let zeroCircle = GeometryNode2D.shape(.circle(radius: 0, segmentCount: 10))
    let zeroBox = GeometryNode3D.shape(.box(size: Vector3D(1, -1, 3)))

    let emptyUnion2D = GeometryNode2D.boolean([], type: .union)
    let emptyUnion3D = GeometryNode3D.boolean([], type: .union)

    @Test func emptyUnion() {
        #expect(emptyUnion2D.isEmpty)
        #expect(emptyUnion3D.isEmpty)
    }

    @Test func singleUnion() {
        let singleUnion2D = GeometryNode2D.boolean([rectangle], type: .union)
        #expect(singleUnion2D == rectangle)

        let singleUnion3D = GeometryNode3D.boolean([box], type: .union)
        #expect(singleUnion3D == box)
    }

    @Test func emptyBaseDifference() {
        let emptyBase2D = GeometryNode2D.boolean([.empty, rectangle], type: .difference)
        #expect(emptyBase2D.isEmpty)

        let nonEmptyBase2D = GeometryNode2D.boolean([rectangle, .empty], type: .difference)
        #expect(nonEmptyBase2D == rectangle)

        let emptyBase3D = GeometryNode3D.boolean([.empty, box], type: .difference)
        #expect(emptyBase3D.isEmpty)

        let nonEmptyBase3D = GeometryNode3D.boolean([box, .empty], type: .difference)
        #expect(nonEmptyBase3D == box)
    }

    @Test func emptyChildrenDifference() {
        let emptyChildren2D = GeometryNode2D.boolean([rectangle, .empty, .empty], type: .difference)
        #expect(emptyChildren2D == rectangle)

        let emptyChildren3D = GeometryNode3D.boolean([box, .empty, .empty], type: .difference)
        #expect(emptyChildren3D == box)
    }

    @Test func zeroSizes() {
        #expect(zeroBox.isEmpty)
        #expect(zeroCircle.isEmpty)
    }

    @Test func zeroSizesInUnion() {
        let zeroUnion2D = GeometryNode2D.boolean([zeroCircle, .empty], type: .union)
        #expect(zeroUnion2D.isEmpty)

        let zeroUnion3D = GeometryNode3D.boolean([.empty, zeroBox], type: .union)
        #expect(zeroUnion3D.isEmpty)
    }

    @Test func emptyOperands() {
        let emptyOffset = GeometryNode2D.offset(.empty, amount: 1.0, joinStyle: .miter, miterLimit: 4.0, segmentCount: 8)
        #expect(emptyOffset.isEmpty)

        let emptyTransform2D = GeometryNode2D.transform(.empty, transform: .identity)
        #expect(emptyTransform2D.isEmpty)

        let emptyExtrusion = GeometryNode3D.extrusion(.empty, type: .linear(height: 10, twist: 0°, divisions: 0, scaleTop: .zero))
        #expect(emptyExtrusion.isEmpty)

        let emptyTransform3D = GeometryNode3D.transform(.empty, transform: .identity)
        #expect(emptyTransform3D.isEmpty)

        let emptyConvexHull = GeometryNode3D.convexHull(.empty)
        #expect(emptyConvexHull.isEmpty)
    }

    @Test func nestedEmptyChildren() {
        let nestedUnion = GeometryNode3D.boolean([
            .empty,
            emptyUnion3D,
            box
        ], type: .union)
        #expect(nestedUnion == box)

        let nestedDifference = GeometryNode3D.boolean([
            .empty,
            emptyUnion3D,
            box
        ], type: .difference)
        #expect(nestedDifference.isEmpty)

        let nestedIntersection = GeometryNode3D.boolean([
            box,
            emptyUnion3D,
            .empty
        ], type: .intersection)
        #expect(nestedIntersection.isEmpty)
    }
}
