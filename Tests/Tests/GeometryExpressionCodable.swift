import Testing
import Foundation
@testable import Cadova

struct GeometryNodeCodableTests {
    @Test func `2D geometry node encodes and decodes correctly`() throws {
        let node: GeometryNode = .boolean([
            .shape(.rectangle(size: .init(x: 10, y: 5))),
            .transform(
                .shape(.circle(radius: 3, segmentCount: 24)),
                transform: .identity
            ),
            .convexHull(
                .offset(
                    .shape(.polygons(
                        SimplePolygonList([
                            SimplePolygon([[0,0 ], [1, 0], [0, 1]])
                        ]),
                        fillRule: .nonZero)
                    ),
                    amount: 1.5,
                    joinStyle: .round,
                    miterLimit: 2.0,
                    segmentCount: 12
                )
            )
        ], type: .union)

        let encoded = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(GeometryNode<D2>.self, from: encoded)
        #expect(decoded == node)
    }

    @Test
    func `3D geometry node encodes and decodes correctly`() throws {
        let node = GeometryNode.boolean([
            .shape(.box(size: .init(x: 5, y: 5, z: 1))),
            .transform(
                .shape(.sphere(radius: 3, segmentCount: 16)),
                transform: .identity
            ),
            .extrusion(
                .boolean([
                    .shape(.circle(radius: 2, segmentCount: 16)),
                    .transform(.shape(.rectangle(size: .init(x: 1, y: 3))), transform: .identity)
                ], type: .difference),
                type: .linear(height: 10, twist: 0°, divisions: 8, scaleTop: .init(x: 1.0, y: 1.0))
            ),
            .refine(
                .smoothOut(
                    .shape(.cylinder(bottomRadius: 2, topRadius: 2, height: 5, segmentCount: 12)),
                    minSharpAngle: 60,
                    minSmoothness: 0.75
                ),
                maxEdgeLength: 0.5
            )
        ], type: .intersection)

        let encoded = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(GeometryNode<D3>.self, from: encoded)
        #expect(decoded == node)
    }
}
