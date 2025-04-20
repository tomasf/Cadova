import Foundation

fileprivate struct Vertex: Hashable {
    let row: Int
    let column: Int
    let kind: Kind

    enum Kind: Hashable {
        case surface (offset: Vector3D)
        case plane (Plane)
        case point (Vector3D)
    }

    static func surface(_ row: Int, _ col: Int) -> Vertex {
        .init(row: row, column: col, kind: .surface(offset: .zero))
    }

    static func plane(_ row: Int, _ col: Int, _ plane: Plane) -> Vertex {
        .init(row: row, column: col, kind: .plane(plane))
    }

    static func offset(_ row: Int, _ col: Int, _ point: Vector3D) -> Vertex {
        .init(row: row, column: col, kind: .surface(offset: point))
    }

    static func fixedPoint(_ point: Vector3D) -> Vertex {
        .init(row: 0, column: 0, kind: .point(point))
    }
}

public extension BezierPatch {
    private enum ExtrusionMode {
        case plane (Plane)
        case point (Vector3D)
        case offset (Vector3D)
    }

    private func extrusion(_ mode: ExtrusionMode, segmentation: EnvironmentValues.Segmentation) -> any Geometry3D {
        let points = points(segmentation: segmentation)
        let lastRow = points.count - 1
        let lastColumn = points[0].count - 1

        // The actual curved Bezier patch
        let surfaceFaces = (0...lastRow).paired().flatMap { r1, r2 in
            (0...lastColumn).paired().flatMap { c1, c2 -> [[Vertex]] in [
                [.surface(r2, c1), .surface(r1, c2), .surface(r1, c1)],
                [.surface(r2, c1), .surface(r2, c2), .surface(r1, c2)]
            ]}
        }

        let allFaces: [[Vertex]]

        switch mode {
        case .plane (let plane):
            // Sides going from the edges of the Bezier surface down to the plane
            let rowSideFaces = (0...lastRow).paired().flatMap { r1, r2 -> [[Vertex]] in [
                [.surface(r2, lastColumn), .plane(r2, lastColumn, plane), .plane(r1, lastColumn, plane), .surface(r1, lastColumn)],
                [.plane(r1, 0, plane), .plane(r2, 0, plane), .surface(r2, 0), .surface(r1, 0)]
            ]}

            let columnSideFaces = (0...lastColumn).paired().flatMap { c1, c2 -> [[Vertex]] in [
                [.surface(0, c2), .plane(0, c2, plane), .plane(0, c1, plane), .surface(0, c1)],
                [.plane(lastRow, c1, plane), .plane(lastRow, c2, plane), .surface(lastRow, c2), .surface(lastRow, c1)]
            ]}

            // The face on the plane connecting the sides
            let bottomFace = (0...lastColumn).map { Vertex.plane(0, $0, plane) }
            + (0...lastRow).map { Vertex.plane($0, lastColumn, plane) }
            + (0...lastColumn).reversed().map { Vertex.plane(lastRow, $0, plane) }
            + (0...lastRow).reversed().map { Vertex.plane($0, 0, plane) }

            allFaces = surfaceFaces + rowSideFaces + columnSideFaces + [bottomFace]

        case .point (let point):
            // Sides going from the edges of the Bezier surface down to the point
            let rowSideFaces = (0...lastRow).paired().flatMap { r1, r2 -> [[Vertex]] in [
                [.surface(r2, lastColumn), .fixedPoint(point), .surface(r1, lastColumn)],
                [.fixedPoint(point), .surface(r2, 0), .surface(r1, 0)]
            ]}

            let columnSideFaces = (0...lastColumn).paired().flatMap { c1, c2 -> [[Vertex]] in [
                [.surface(0, c2), .fixedPoint(point), .surface(0, c1)],
                [.fixedPoint(point), .surface(lastRow, c2), .surface(lastRow, c1)]
            ]}

            allFaces = surfaceFaces + rowSideFaces + columnSideFaces

        case .offset (let offset):
            // Sides going from the edges of the Bezier surface down to the plane
            let rowSideFaces = (0...lastRow).paired().flatMap { r1, r2 -> [[Vertex]] in [
                [.surface(r2, lastColumn), .offset(r2, lastColumn, offset), .offset(r1, lastColumn, offset), .surface(r1, lastColumn)],
                [.offset(r1, 0, offset), .offset(r2, 0, offset), .surface(r2, 0), .surface(r1, 0)]
            ]}

            let columnSideFaces = (0...lastColumn).paired().flatMap { c1, c2 -> [[Vertex]] in [
                [.surface(0, c2), .offset(0, c2, offset), .offset(0, c1, offset), .surface(0, c1)],
                [.offset(lastRow, c1, offset), .offset(lastRow, c2, offset), .surface(lastRow, c2), .surface(lastRow, c1)]
            ]}

            // The bottom offset curved Bezier patch
            let bottomFaces = (0...lastRow).paired().flatMap { r1, r2 in
                (0...lastColumn).paired().flatMap { c1, c2 -> [[Vertex]] in [
                    [.offset(r1, c1, offset), .offset(r1, c2, offset), .offset(r2, c1, offset)],
                    [.offset(r1, c2, offset), .offset(r2, c2, offset), .offset(r2, c1, offset)]
                ]}
            }

            allFaces = surfaceFaces + rowSideFaces + columnSideFaces + bottomFaces
        }

        return Polyhedron(faces: allFaces) { vertex in
            return switch vertex.kind {
            case .surface (let offset): points[vertex.row][vertex.column] + offset
            case .plane (let plane): plane.project(point: points[vertex.row][vertex.column])
            case .point (let point): point
            }
        }.correctingFaceWinding()
    }


    func extruded(to plane: Plane) -> any Geometry3D {
        readEnvironment(\.segmentation) { segments in
            extrusion(.plane(plane), segmentation: segments)
        }
    }

    func extruded(to point: Vector3D) -> any Geometry3D {
        readEnvironment(\.segmentation) { segments in
            extrusion(.point(point), segmentation: segments)
        }
    }

    func extruded(offset: Vector3D) -> any Geometry3D {
        readEnvironment(\.segmentation) { segments in
            extrusion(.offset(offset), segmentation: segments)
        }
    }
}
