import Foundation

fileprivate struct Vertex: Hashable {
    let row: Int
    let column: Int
    let onPlane: Bool
}

public extension BezierPatch {
    func extrude(base plane: Plane) -> any Geometry3D {
        readEnvironment(\.facets) { facets in
            let points = points(facets: facets)
            let rows = points.count
            let columns = points[0].count

            let surface = (0..<rows).paired().flatMap { r1, r2 in
                (0..<columns).paired().flatMap { c1, c2 in
                    [
                        [
                            Vertex(row: r2, column: c1, onPlane: false),
                            Vertex(row: r1, column: c2, onPlane: false),
                            Vertex(row: r1, column: c1, onPlane: false),
                        ],[
                            Vertex(row: r2, column: c1, onPlane: false),
                            Vertex(row: r2, column: c2, onPlane: false),
                            Vertex(row: r1, column: c2, onPlane: false),
                        ]
                    ]
                }
            }

            let rowSides = (0..<rows).paired().flatMap { r1, r2 in
                [
                    [
                        Vertex(row: r2, column: columns-1, onPlane: false),
                        Vertex(row: r2, column: columns-1, onPlane: true),
                        Vertex(row: r1, column: columns-1, onPlane: true),
                        Vertex(row: r1, column: columns-1, onPlane: false),
                    ],[
                        Vertex(row: r1, column: 0, onPlane: true),
                        Vertex(row: r2, column: 0, onPlane: true),
                        Vertex(row: r2, column: 0, onPlane: false),
                        Vertex(row: r1, column: 0, onPlane: false),
                    ]
                ]
            }

            let columnSides = (0..<columns).paired().flatMap { c1, c2 in
                [
                    [
                        Vertex(row: 0, column: c2, onPlane: false),
                        Vertex(row: 0, column: c2, onPlane: true),
                        Vertex(row: 0, column: c1, onPlane: true),
                        Vertex(row: 0, column: c1, onPlane: false),
                    ],[
                        Vertex(row: rows-1, column: c1, onPlane: true),
                        Vertex(row: rows-1, column: c2, onPlane: true),
                        Vertex(row: rows-1, column: c2, onPlane: false),
                        Vertex(row: rows-1, column: c1, onPlane: false),
                    ]
                ]
            }

            let bottom = (0..<columns).map { Vertex(row: 0, column: $0, onPlane: true) }
            + (0..<rows).map { Vertex(row: $0, column: columns - 1, onPlane: true) }
            + (0..<columns).reversed().map { Vertex(row: rows - 1, column: $0, onPlane: true) }
            + (0..<rows).reversed().map { Vertex(row: $0, column: 0, onPlane: true) }

            let allFaces = surface + rowSides + columnSides + [bottom]

            Polyhedron(faces: allFaces) { vertex in
                let p = points[vertex.row][vertex.column]
                return vertex.onPlane ? plane.project(point: p) : p
            }.correctingFaceWinding()
        }
    }
}
