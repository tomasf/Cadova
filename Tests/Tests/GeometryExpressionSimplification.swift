import Foundation
import Testing
@testable import Cadova

struct GeometryNodeSimplificationTests {
    let rectangle = GeometryNode.shape(.rectangle(size: Vector2D(1, 2)))
    let box = GeometryNode.shape(.box(size: Vector3D(1, 2, 3)))
    let zeroCircle = GeometryNode.shape(.circle(radius: 0, segmentCount: 10))
    let zeroBox = GeometryNode.shape(.box(size: Vector3D(1, -1, 3)))

    let emptyUnion2D = GeometryNode<D2>.boolean([], type: .union)
    let emptyUnion3D = GeometryNode<D3>.boolean([], type: .union)

    @Test func `empty union simplifies to empty`() {
        #expect(emptyUnion2D.isEmpty)
        #expect(emptyUnion3D.isEmpty)
    }

    @Test func `single child union simplifies to child`() {
        let singleUnion2D = GeometryNode.boolean([rectangle], type: .union)
        #expect(singleUnion2D == rectangle)

        let singleUnion3D = GeometryNode.boolean([box], type: .union)
        #expect(singleUnion3D == box)
    }

    @Test func `difference with empty base simplifies correctly`() {
        let emptyBase2D = GeometryNode.boolean([.empty, rectangle], type: .difference)
        #expect(emptyBase2D.isEmpty)

        let nonEmptyBase2D = GeometryNode.boolean([rectangle, .empty], type: .difference)
        #expect(nonEmptyBase2D == rectangle)

        let emptyBase3D = GeometryNode.boolean([.empty, box], type: .difference)
        #expect(emptyBase3D.isEmpty)

        let nonEmptyBase3D = GeometryNode.boolean([box, .empty], type: .difference)
        #expect(nonEmptyBase3D == box)
    }

    @Test func `difference with empty children simplifies to base`() {
        let emptyChildren2D = GeometryNode.boolean([rectangle, .empty, .empty], type: .difference)
        #expect(emptyChildren2D == rectangle)

        let emptyChildren3D = GeometryNode.boolean([box, .empty, .empty], type: .difference)
        #expect(emptyChildren3D == box)
    }

    @Test func `zero-sized shapes simplify to empty`() {
        #expect(zeroBox.isEmpty)
        #expect(zeroCircle.isEmpty)
    }

    @Test func `union of zero-sized shapes simplifies to empty`() {
        let zeroUnion2D = GeometryNode.boolean([zeroCircle, .empty], type: .union)
        #expect(zeroUnion2D.isEmpty)

        let zeroUnion3D = GeometryNode.boolean([.empty, zeroBox], type: .union)
        #expect(zeroUnion3D.isEmpty)
    }

    @Test func `operations on empty operands simplify to empty`() {
        let emptyOffset = GeometryNode.offset(.empty, amount: 1.0, joinStyle: .miter, miterLimit: 4.0, segmentCount: 8)
        #expect(emptyOffset.isEmpty)

        let emptyTransform2D = GeometryNode<D2>.transform(.empty, transform: .identity)
        #expect(emptyTransform2D.isEmpty)

        let emptyExtrusion = GeometryNode.extrusion(.empty, type: .linear(height: 10, twist: 0°, divisions: 0, scaleTop: .zero))
        #expect(emptyExtrusion.isEmpty)

        let emptyTransform3D = GeometryNode<D3>.transform(.empty, transform: .identity)
        #expect(emptyTransform3D.isEmpty)

        let emptyConvexHull = GeometryNode<D3>.convexHull(.empty)
        #expect(emptyConvexHull.isEmpty)
    }

    @Test func `nested empty children simplify correctly`() {
        let nestedUnion = GeometryNode.boolean([
            .empty,
            emptyUnion3D,
            box
        ], type: .union)
        #expect(nestedUnion == box)

        let nestedDifference = GeometryNode.boolean([
            .empty,
            emptyUnion3D,
            box
        ], type: .difference)
        #expect(nestedDifference.isEmpty)

        let nestedIntersection = GeometryNode.boolean([
            box,
            emptyUnion3D,
            .empty
        ], type: .intersection)
        #expect(nestedIntersection.isEmpty)
    }
}
