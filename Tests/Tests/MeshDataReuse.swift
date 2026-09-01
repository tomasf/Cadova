import Foundation
import Testing
@testable import Cadova

/// Counts how many times a mesh resolves a vertex key to a position.
///
/// Building a mesh's `MeshData` calls the mesh's `value` closure exactly once per distinct vertex key, so this
/// count says how many times that table was built — a timing-independent way to catch the table being rebuilt
/// per query, or built eagerly for a mesh nobody asked about.
private final class VertexLookupCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        value += 1
    }
}

/// The outward-facing triangles of a cube subdivided into `divisions` × `divisions` quads per side.
///
/// The shape has a closed form to check against — a cube of side `side` has a surface area of `6 · side²` and a
/// volume of `side³` — while its triangle count grows as `12 · divisions²`, which makes it a stand-in for the
/// large meshes sweeps and lofts produce.
private func subdividedCubeFaces(side: Double, divisions: Int) -> [[Vector3D]] {
    // Each entry places one side of the cube: a corner, and two edge vectors whose cross product points out of
    // the cube, so walking a quad from the corner outward winds counterclockwise as seen from outside.
    let sides: [(corner: Vector3D, u: Vector3D, v: Vector3D)] = [
        (Vector3D(0, 0, side), Vector3D(side, 0, 0), Vector3D(0, side, 0)),
        (Vector3D(0, 0, 0), Vector3D(0, side, 0), Vector3D(side, 0, 0)),
        (Vector3D(side, 0, 0), Vector3D(0, side, 0), Vector3D(0, 0, side)),
        (Vector3D(0, 0, 0), Vector3D(0, 0, side), Vector3D(0, side, 0)),
        (Vector3D(0, side, 0), Vector3D(0, 0, side), Vector3D(side, 0, 0)),
        (Vector3D(0, 0, 0), Vector3D(side, 0, 0), Vector3D(0, 0, side)),
    ]

    var faces: [[Vector3D]] = []
    faces.reserveCapacity(sides.count * divisions * divisions * 2)

    for placement in sides {
        for i in 0..<divisions {
            for j in 0..<divisions {
                let uStart = Double(i) / Double(divisions)
                let uEnd = Double(i + 1) / Double(divisions)
                let vStart = Double(j) / Double(divisions)
                let vEnd = Double(j + 1) / Double(divisions)

                let corner00 = placement.corner + placement.u * uStart + placement.v * vStart
                let corner10 = placement.corner + placement.u * uEnd + placement.v * vStart
                let corner11 = placement.corner + placement.u * uEnd + placement.v * vEnd
                let corner01 = placement.corner + placement.u * uStart + placement.v * vEnd

                faces.append([corner00, corner10, corner11])
                faces.append([corner00, corner11, corner01])
            }
        }
    }

    return faces
}

private func subdividedCube(side: Double, divisions: Int) -> Mesh<Vector3D> {
    Mesh(
        faces: subdividedCubeFaces(side: side, divisions: divisions),
        name: "Tests.SubdividedCube",
        cacheParameters: side, divisions
    )
}

private func subdividedCube(side: Double, divisions: Int, counting counter: VertexLookupCounter) -> Mesh<Vector3D> {
    Mesh(
        faces: subdividedCubeFaces(side: side, divisions: divisions),
        name: "Tests.SubdividedCube",
        cacheParameters: side, divisions
    ) { vertex in
        counter.increment()
        return vertex
    }
}

// The distinct positions on the surface of a cube subdivided this many times: every lattice point of the
// (divisions + 1)³ grid that isn't strictly interior.
private func surfaceVertexCount(divisions: Int) -> Int {
    let n = divisions + 1
    let interior = Swift.max(divisions - 1, 0)
    return n * n * n - interior * interior * interior
}

struct MeshDataReuseTests {
    @Test func `mesh does not build its vertex table until something asks for it`() {
        let counter = VertexLookupCounter()
        _ = subdividedCube(side: 10, divisions: 6, counting: counter)

        // `body` wraps the mesh in a `CachedNode`, so a mesh whose geometry is already cached never needs its
        // vertex table. Building it during construction would charge every sweep and loft for work it may throw
        // away.
        #expect(counter.count == 0)
    }

    @Test func `mesh builds its vertex table only once, however often it is queried`() {
        let counter = VertexLookupCounter()
        let mesh = subdividedCube(side: 10, divisions: 6, counting: counter)
        let expectedLookups = surfaceVertexCount(divisions: 6)

        let area = mesh.surfaceArea
        #expect(counter.count == expectedLookups)

        // `surfaceArea` used to read `meshData` once per vertex reference, rebuilding the whole table each time.
        let volume = mesh.volume
        _ = mesh.faces
        _ = mesh.meshData
        #expect(counter.count == expectedLookups)

        #expect(area ≈ 600)
        #expect(volume ≈ 1000)
    }

    @Test func `correcting face winding leaves an outward mesh alone and reuses its vertex table`() {
        let counter = VertexLookupCounter()
        let corrected = subdividedCube(side: 10, divisions: 6, counting: counter).correctingFaceWinding()

        // The corrected mesh's cache key doesn't depend on the winding, so the check itself can wait.
        #expect(counter.count == 0)

        #expect(corrected.volume ≈ 1000)
        #expect(corrected.surfaceArea ≈ 600)

        // The winding was already outward, so the table built to determine that describes the corrected mesh too.
        #expect(counter.count == surfaceVertexCount(divisions: 6))
    }

    @Test func `correcting face winding flips an inside-out mesh`() {
        let counter = VertexLookupCounter()
        let insideOut = Mesh(
            faces: subdividedCubeFaces(side: 10, divisions: 6).map { $0.reversed() },
            name: "Tests.SubdividedCube.InsideOut",
            cacheParameters: 6
        ) { (vertex: Vector3D) in
            counter.increment()
            return vertex
        }

        #expect(insideOut.volume ≈ -1000)
        #expect(insideOut.correctingFaceWinding().volume ≈ 1000)
    }

    @Test func `mesh measurements match the values from before mesh data was reused`() {
        // Recorded from the implementation that rebuilt `meshData` on every access, to show that memoizing it
        // changes only how often the table is built, never what it contains.
        #expect(subdividedCube(side: 10, divisions: 6).surfaceArea.equals(600.0000000000057, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 6).volume.equals(999.9999999999964, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 13).surfaceArea.equals(600.0000000000034, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 13).volume.equals(1000.0000000000131, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 26).surfaceArea.equals(599.9999999999311, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 26).volume.equals(1000.000000000044, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 52).surfaceArea.equals(600.0000000001305, within: 1e-9))
        #expect(subdividedCube(side: 10, divisions: 52).volume.equals(999.9999999997044, within: 1e-9))
    }
}
