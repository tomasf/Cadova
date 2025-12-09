import Foundation

internal struct EnclosePatchVertex: Hashable, Codable {
    let row: Int
    let column: Int
    let kind: Kind

    enum Kind: Hashable, Codable {
        case surface (offset: Vector3D)
        case plane (Plane)
        case point (Vector3D)
    }

    static func surface(_ row: Int, _ col: Int) -> EnclosePatchVertex {
        .init(row: row, column: col, kind: .surface(offset: .zero))
    }

    static func plane(_ row: Int, _ col: Int, _ plane: Plane) -> EnclosePatchVertex {
        .init(row: row, column: col, kind: .plane(plane))
    }

    static func offset(_ row: Int, _ col: Int, _ point: Vector3D) -> EnclosePatchVertex {
        .init(row: row, column: col, kind: .surface(offset: point))
    }

    static func fixedPoint(_ point: Vector3D) -> EnclosePatchVertex {
        .init(row: 0, column: 0, kind: .point(point))
    }
}

internal extension BezierPatch {
    enum EnclosureMode: Sendable, Hashable, Codable {
        case plane (Plane)
        case point (Vector3D)
        case offset (Vector3D)
    }

    private func enclosed(to mode: EnclosureMode, segmentation: Segmentation) -> any Geometry3D {
        let points = points(segmentation: segmentation)
        let lastRow = points.count - 1
        let lastColumn = points[0].count - 1

        // The actual curved Bezier patch
        let surfaceFaces = (0...lastRow).paired().flatMap { r1, r2 in
            (0...lastColumn).paired().flatMap { c1, c2 -> [[EnclosePatchVertex]] in [
                [.surface(r2, c1), .surface(r1, c2), .surface(r1, c1)],
                [.surface(r2, c1), .surface(r2, c2), .surface(r1, c2)]
            ]}
        }

        let allFaces: [[EnclosePatchVertex]]

        switch mode {
        case .plane (let plane):
            // Sides going from the edges of the Bezier surface down to the plane
            let rowSideFaces = (0...lastRow).paired().flatMap { r1, r2 -> [[EnclosePatchVertex]] in [
                [.surface(r2, lastColumn), .plane(r2, lastColumn, plane), .plane(r1, lastColumn, plane), .surface(r1, lastColumn)],
                [.plane(r1, 0, plane), .plane(r2, 0, plane), .surface(r2, 0), .surface(r1, 0)]
            ]}

            let columnSideFaces = (0...lastColumn).paired().flatMap { c1, c2 -> [[EnclosePatchVertex]] in [
                [.surface(0, c2), .plane(0, c2, plane), .plane(0, c1, plane), .surface(0, c1)],
                [.plane(lastRow, c1, plane), .plane(lastRow, c2, plane), .surface(lastRow, c2), .surface(lastRow, c1)]
            ]}

            // The face on the plane connecting the sides
            let bottomFace = (0...lastColumn).map { EnclosePatchVertex.plane(0, $0, plane) }
            + (0...lastRow).map { EnclosePatchVertex.plane($0, lastColumn, plane) }
            + (0...lastColumn).reversed().map { EnclosePatchVertex.plane(lastRow, $0, plane) }
            + (0...lastRow).reversed().map { EnclosePatchVertex.plane($0, 0, plane) }

            allFaces = surfaceFaces + rowSideFaces + columnSideFaces + [bottomFace]

        case .point (let point):
            // Sides going from the edges of the Bezier surface down to the point
            let rowSideFaces = (0...lastRow).paired().flatMap { r1, r2 -> [[EnclosePatchVertex]] in [
                [.surface(r2, lastColumn), .fixedPoint(point), .surface(r1, lastColumn)],
                [.fixedPoint(point), .surface(r2, 0), .surface(r1, 0)]
            ]}

            let columnSideFaces = (0...lastColumn).paired().flatMap { c1, c2 -> [[EnclosePatchVertex]] in [
                [.surface(0, c2), .fixedPoint(point), .surface(0, c1)],
                [.fixedPoint(point), .surface(lastRow, c2), .surface(lastRow, c1)]
            ]}

            allFaces = surfaceFaces + rowSideFaces + columnSideFaces

        case .offset (let offset):
            // Sides going from the edges of the Bezier surface down to the plane
            let rowSideFaces = (0...lastRow).paired().flatMap { r1, r2 -> [[EnclosePatchVertex]] in [
                [.surface(r2, lastColumn), .offset(r2, lastColumn, offset), .offset(r1, lastColumn, offset), .surface(r1, lastColumn)],
                [.offset(r1, 0, offset), .offset(r2, 0, offset), .surface(r2, 0), .surface(r1, 0)]
            ]}

            let columnSideFaces = (0...lastColumn).paired().flatMap { c1, c2 -> [[EnclosePatchVertex]] in [
                [.surface(0, c2), .offset(0, c2, offset), .offset(0, c1, offset), .surface(0, c1)],
                [.offset(lastRow, c1, offset), .offset(lastRow, c2, offset), .surface(lastRow, c2), .surface(lastRow, c1)]
            ]}

            // The bottom offset curved Bezier patch
            let bottomFaces = (0...lastRow).paired().flatMap { r1, r2 in
                (0...lastColumn).paired().flatMap { c1, c2 -> [[EnclosePatchVertex]] in [
                    [.offset(r1, c1, offset), .offset(r1, c2, offset), .offset(r2, c1, offset)],
                    [.offset(r1, c2, offset), .offset(r2, c2, offset), .offset(r2, c1, offset)]
                ]}
            }

            allFaces = surfaceFaces + rowSideFaces + columnSideFaces + bottomFaces
        }

        return Mesh(faces: allFaces, name: "EncloseBezierPatch", cacheParameters: self, mode, segmentation) { vertex in
            return switch vertex.kind {
            case .surface (let offset): points[vertex.row][vertex.column] + offset
            case .plane (let plane): plane.project(point: points[vertex.row][vertex.column])
            case .point (let point): point
            }
        }.correctingFaceWinding()
    }

}

public extension BezierPatch {
    /// Encloses this Bézier patch against a plane, producing a closed 3D solid.
    ///
    /// The method spans ruled side faces from the patch’s boundary to the given `plane`, then
    /// closes the shape with a planar face on the plane. This converts the open surface into a
    /// volumetric body.
    ///
    /// The tessellation density of the curved patch is controlled by the current environment’s
    /// ``EnvironmentValues/segmentation``.
    ///
    /// - Parameter plane: The plane used to cap the patch; side walls are built from the patch edge to this plane.
    /// - Returns: A 3D geometry representing the enclosed solid.
    ///
    /// - SeeAlso: ``enclosed(to:)``
    /// - SeeAlso: ``enclosed(offset:)``
    func enclosed(against plane: Plane) -> any Geometry3D {
        readEnvironment(\.scaledSegmentation) { segments in
            enclosed(to: .plane(plane), segmentation: segments)
        }
    }

    /// Encloses this Bézier patch to an apex point, producing a closed 3D solid.
    ///
    /// The method spans ruled side faces from the patch’s boundary to the single apex `point`.
    /// This yields a tapered, tent‑like solid whose base is the original patch.
    ///
    /// The tessellation density of the curved patch is controlled by the current environment’s
    /// ``EnvironmentValues/segmentation``.
    ///
    /// - Parameter point: The apex point to which the patch boundary is connected.
    /// - Returns: A 3D geometry representing the enclosed solid.
    ///
    /// - SeeAlso: ``enclosed(against:)``
    /// - SeeAlso: ``enclosed(offset:)``
    func enclosed(to point: Vector3D) -> any Geometry3D {
        readEnvironment(\.scaledSegmentation) { segments in
            enclosed(to: .point(point), segmentation: segments)
        }
    }

    /// Encloses this Bézier patch with an offset copy of itself, producing a closed 3D solid.
    ///
    /// The method constructs a second patch translated by `offset`, then spans ruled side faces
    /// between the two patches and caps the opposite side with the offset patch, forming a thickened
    /// volume.
    ///
    /// The tessellation density of the curved patches is controlled by the current environment’s
    /// ``EnvironmentValues/segmentation``.
    ///
    /// - Parameter offset: The translation applied to form the second patch used to close the volume.
    /// - Returns: A 3D geometry representing the enclosed solid.
    ///
    /// - SeeAlso: ``enclosed(against:)``
    /// - SeeAlso: ``enclosed(to:)``
    func enclosed(offset: Vector3D) -> any Geometry3D {
        readEnvironment(\.scaledSegmentation) { segments in
            enclosed(to: .offset(offset), segmentation: segments)
        }
    }
}
