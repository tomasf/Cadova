import Testing
@testable import Cadova

// A unit cube as six quads, wound counter-clockwise seen from outside.
private let cubeVertices: [Vector3D] = [
    [0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0],
    [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1],
]

private let cubeQuads: [MeshData.Face] = [
    [0, 3, 2, 1], // bottom
    [4, 5, 6, 7], // top
    [0, 1, 5, 4], // front
    [2, 3, 7, 6], // back
    [0, 4, 7, 3], // left
    [1, 2, 6, 5], // right
]

private let red = Material(baseColor: .red)
private let green = Material(baseColor: .green)
private let blue = Material(baseColor: .blue)

struct MeshDataMaterialTests {
    @Test func `a mesh without materials evaluates to a single original with no mapping`() throws {
        let result = try MeshData(vertices: cubeVertices, faces: cubeQuads).evaluate()

        #expect(result.materialMapping.isEmpty)
        #expect(result.concrete.originalID != nil)
        #expect(result.concrete.meshGL().originalIDs.count == 1)
    }

    @Test func `quads keep their materials when triangulated`() throws {
        // Opposite faces share a material, so each material covers two quads: four triangles.
        let faceMaterials = MeshData.FaceMaterials(perFace: [red, red, green, green, blue, blue])
        let mesh = MeshData(vertices: cubeVertices, faces: cubeQuads, faceMaterials: faceMaterials)
        let result = try mesh.evaluate()

        #expect(result.concrete.volume ≈ 1)
        #expect(Set(result.materialMapping.values) == [red, green, blue])

        let triangleCounts = result.concrete.meshGL().originalIDs.mapValues(\.count)
        #expect(triangleCounts.count == 3)
        for (originalID, material) in result.materialMapping {
            #expect(triangleCounts[originalID] == 4, "\(material) should cover four triangles")
        }
    }

    @Test func `faces without a material share an original ID that maps to nothing`() throws {
        let faceMaterials = MeshData.FaceMaterials(perFace: [red, nil, nil, red, nil, blue])
        let mesh = MeshData(vertices: cubeVertices, faces: cubeQuads, faceMaterials: faceMaterials)
        let result = try mesh.evaluate()

        #expect(Set(result.materialMapping.values) == [red, blue])

        let triangleCounts = result.concrete.meshGL().originalIDs.mapValues(\.count)
        #expect(triangleCounts.count == 3)
        let unmapped = Set(triangleCounts.keys).subtracting(result.materialMapping.keys)
        #expect(unmapped.count == 1)
        #expect(triangleCounts[unmapped.first!] == 6)
    }

    @Test func `materials that no face uses take part in nothing`() throws {
        let allUnset = MeshData.FaceMaterials(perFace: [nil, nil, nil, nil, nil, nil])
        #expect(allUnset.materials.isEmpty)

        let result = try MeshData(vertices: cubeVertices, faces: cubeQuads, faceMaterials: allUnset).evaluate()
        #expect(result.materialMapping.isEmpty)
        #expect(result.concrete.meshGL().originalIDs.count == 1)
    }

    @Test func `face materials share one palette entry per distinct material`() {
        let faceMaterials = MeshData.FaceMaterials(perFace: [red, blue, red, nil, blue, red])
        #expect(faceMaterials.materials.count == 2)
        #expect(faceMaterials.indices.map { $0.map { faceMaterials.materials[$0] } } == [red, blue, red, nil, blue, red])
    }

    @Test func `meshes differing only in materials are different`() {
        let plain = MeshData(vertices: cubeVertices, faces: cubeQuads)
        let colored = MeshData(vertices: cubeVertices, faces: cubeQuads, faceMaterials: .init(perFace: [red, red, red, red, red, red]))
        let recolored = MeshData(vertices: cubeVertices, faces: cubeQuads, faceMaterials: .init(perFace: [blue, blue, blue, blue, blue, blue]))

        #expect(plain != colored)
        #expect(colored != recolored)
        #expect(colored == MeshData(vertices: cubeVertices, faces: cubeQuads, faceMaterials: .init(perFace: [red, red, red, red, red, red])))
    }
}
