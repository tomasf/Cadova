import Testing
@testable import Cadova

struct BezierPatchTests {
    @Test func `bezier patch can be enclosed into solid geometry`() async throws {
        let patch = BezierPatch(controlPoints: [
            [ [0, 0, 0],   [1, 0, 0.8],   [2, 0, -0.2],  [3, 0, 0] ],
            [ [0, 1, 0.5], [1, 1, 1.5],   [2, 1, 0.3],   [3, 1, -0.4] ],
            [ [0, 2, 0.4], [1, 2, 1.2],   [2, 2, 1],     [3, 2, 0.2] ],
            [ [0, 3, 0],   [1, 3, 0.4],   [2, 3, 0.1],   [3, 3, 1.2] ]
        ])

        try await patch.enclosed(against: Plane.z(-0.5))
            .aligned(at: .bottom)
            .expectEquals(goldenFile: "bezierPatchBasic")
    }

    private static let patch = BezierPatch(controlPoints: [
        [ [0, 0, 0],   [1, 0, 0.8],   [2, 0, -0.2],  [3, 0, 0] ],
        [ [0, 1, 0.5], [1, 1, 1.5],   [2, 1, 0.3],   [3, 1, -0.4] ],
        [ [0, 2, 0.4], [1, 2, 1.2],   [2, 2, 1],     [3, 2, 0.2] ],
        [ [0, 3, 0],   [1, 3, 0.4],   [2, 3, 0.1],   [3, 3, 1.2] ]
    ])

    private static let parameters = stride(from: 0.0, through: 1.0, by: 0.125)

    @Test func `patch corners are its corner control points`() {
        #expect(Self.patch.point(at: [0, 0]) ≈ [0, 0, 0])
        #expect(Self.patch.point(at: [0, 1]) ≈ [3, 0, 0])
        #expect(Self.patch.point(at: [1, 0]) ≈ [0, 3, 0])
        #expect(Self.patch.point(at: [1, 1]) ≈ [3, 3, 1.2])
    }

    @Test func `patch edges are the Bezier curves of its boundary control points`() {
        let rows = Self.patch.controlPoints
        let firstRow = BezierCurve(controlPoints: rows.first!)
        let lastRow = BezierCurve(controlPoints: rows.last!)
        let firstColumn = BezierCurve(controlPoints: rows.map(\.first!))
        let lastColumn = BezierCurve(controlPoints: rows.map(\.last!))

        for t in Self.parameters {
            #expect(Self.patch.point(at: [0, t]) ≈ firstRow.point(at: t))
            #expect(Self.patch.point(at: [1, t]) ≈ lastRow.point(at: t))
            #expect(Self.patch.point(at: [t, 0]) ≈ firstColumn.point(at: t))
            #expect(Self.patch.point(at: [t, 1]) ≈ lastColumn.point(at: t))
        }
    }

    @Test func `patch with a two by two grid is bilinear`() {
        let patch = BezierPatch(controlPoints: [
            [[0, 0, 0], [10, 0, 0]],
            [[0, 10, 0], [10, 10, 5]]
        ])
        for u in Self.parameters {
            for v in Self.parameters {
                #expect(patch.point(at: [u, v]) ≈ Vector3D(10 * v, 10 * u, 5 * u * v))
            }
        }
    }

    @Test func `transforming a patch transforms its surface`() {
        let transform = Transform3D.rotation(x: 30°, y: -15°, z: 70°).translated(x: 5, y: -2, z: 8)
        let transformed = Self.patch.transformed(transform)
        for u in Self.parameters {
            for v in Self.parameters {
                #expect(transformed.point(at: [u, v]) ≈ transform.apply(to: Self.patch.point(at: [u, v])))
            }
        }
    }

    @Test func `fixed segmentation samples a uniform grid`() {
        let grid = Self.patch.points(segmentation: .fixed(4))
        #expect(grid.count == 5)
        #expect(grid.allSatisfy { $0.count == 5 })
        for (i, row) in grid.enumerated() {
            for (j, point) in row.enumerated() {
                #expect(point ≈ Self.patch.point(at: [Double(i) / 4, Double(j) / 4]))
            }
        }
    }

    @Test func `adaptive segmentation keeps every grid cell below the requested size`() {
        let minSize = 0.4
        let grid = Self.patch.points(segmentation: .adaptive(minAngle: 5°, minSize: minSize))
        #expect(grid.first!.first! ≈ [0, 0, 0])
        #expect(grid.last!.last! ≈ [3, 3, 1.2])
        for i in 0..<(grid.count - 1) {
            for j in 0..<(grid[i].count - 1) {
                #expect(grid[i][j].distance(to: grid[i + 1][j]) <= minSize)
                #expect(grid[i][j].distance(to: grid[i][j + 1]) <= minSize)
            }
        }
    }
}
