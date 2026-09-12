import Foundation
import Testing
import ThreeMF
@testable import Cadova

/// Materials reaching the evaluated geometry, regardless of which faces carry them.
private func materials(of geometry: any Geometry3D) async throws -> Set<Material> {
    Set(try await geometry.evaluationResult.materialMapping.values)
}

private func temporary3MFURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("cadova-test-\(UUID().uuidString).3mf")
}

/// The surface area each color covers in a single-model 3MF file, resolving triangle and object
/// properties the way a reader of the file would. Triangles without a color are left out.
///
/// This repeats the core specification's property rule on purpose rather than going through the
/// loader, so that it checks the files Cadova writes against the format and not against itself.
private func colorAreas(in url: URL) throws -> [ThreeMF.Color: Double] {
    let model = try ThreeMF.PackageReader(url: url).model()
    var areas: [ThreeMF.Color: Double] = [:]

    for case let object as ThreeMF.Object in model.resources.resources {
        guard case .mesh (let mesh) = object.content else { continue }
        for triangle in mesh.triangles {
            let groupID = triangle.propertyGroup ?? object.propertyGroupID
            let index = triangle.propertyIndex?.indices[0] ?? object.propertyIndex
            guard let groupID, let index,
                  let group = model.resources.resource(for: groupID) as? ThreeMF.ColorGroup
            else { continue }

            let corners = [triangle.v1, triangle.v2, triangle.v3].map {
                let vertex = mesh.vertices[$0]
                return Vector3D(vertex.x, vertex.y, vertex.z)
            }
            let area = ((corners[1] - corners[0]) × (corners[2] - corners[0])).magnitude / 2
            areas[group.colors[index], default: 0] += area
        }
    }
    return areas
}

private let threeMFRed = ThreeMF.Color(red: 255, green: 0, blue: 0)
private let threeMFBlue = ThreeMF.Color(red: 0, green: 0, blue: 255)

private let boxSize = 10.0

/// The surface one color covers on a box of `boxSize` after its neighbor hides one face.
private let coloredArea = boxSize * boxSize * 5

/// Two touching boxes in different colors, so the union carries both on its surface.
private var twoColoredBoxes: any Geometry3D {
    Box(boxSize).colored(.red)
        .adding {
            Box(boxSize)
                .translated(x: boxSize)
                .colored(.blue)
        }
}

/// The corners of a unit cube's twelve triangles, two per face, in the order bottom, top, front,
/// back, left, right.
private let unitCubeVertices: [ThreeMF.Mesh.Vertex] = [
    .init(x: 0, y: 0, z: 0), .init(x: 1, y: 0, z: 0), .init(x: 1, y: 1, z: 0), .init(x: 0, y: 1, z: 0),
    .init(x: 0, y: 0, z: 1), .init(x: 1, y: 0, z: 1), .init(x: 1, y: 1, z: 1), .init(x: 0, y: 1, z: 1),
]
private let unitCubeCorners: [(Int, Int, Int)] = [
    (0, 2, 1), (0, 3, 2),
    (4, 5, 6), (4, 6, 7),
    (0, 1, 5), (0, 5, 4),
    (2, 3, 7), (2, 7, 6),
    (0, 4, 7), (0, 7, 3),
    (1, 2, 6), (1, 6, 5),
]

private typealias TriangleProperty = (index: ThreeMF.Mesh.Triangle.Index?, group: ResourceID?)

/// A single-model 3MF package holding the given resources and a unit cube whose triangles take
/// the given properties, one per triangle in the order of `unitCubeCorners`.
private func unitCubePackage(
    resources: [any ThreeMF.Resource],
    objectProperty: PropertyReference? = nil,
    triangleProperties: [TriangleProperty]
) async throws -> Data {
    let triangles = zip(unitCubeCorners, triangleProperties).map { corner, property in
        ThreeMF.Mesh.Triangle(v1: corner.0, v2: corner.1, v3: corner.2, propertyIndex: property.index, propertyGroup: property.group)
    }
    let object = ThreeMF.Object(
        id: 40, propertyGroupID: objectProperty?.groupID, propertyIndex: objectProperty?.index,
        content: .mesh(.init(vertices: unitCubeVertices, triangles: triangles))
    )
    let writer = ThreeMF.PackageWriter<Data>()
    writer.model = ThreeMF.Model(
        unit: .millimeter,
        recommendedExtensions: [.materials],
        resources: resources + [object],
        build: .init(items: [.init(objectID: object.id)])
    )
    return try await writer.finalize()
}

/// Gives every face of the cube the same property.
private func allFaces(_ property: TriangleProperty) -> [TriangleProperty] {
    Array(repeating: property, count: unitCubeCorners.count)
}

private let threeMFOrange = ThreeMF.Color(red: 255, green: 128, blue: 0)
private let orange = Color(red: 1, green: 128.0 / 255.0, blue: 0)
private let brushed = ThreeMF.Metallic(name: "Brushed", metallicness: 0.5, roughness: 0.25)

/// Orange steel with brushed display properties, as base material group 1 with display
/// properties 5.
private let steelResources: [any ThreeMF.Resource] = [
    ThreeMF.MetallicDisplayProperties(id: 5, metallics: [brushed]),
    ThreeMF.BaseMaterialGroup(id: 1, displayPropertiesID: 5, properties: [.init(name: "Steel", displayColor: threeMFOrange)]),
]
private let steel = Material(name: "Steel", baseColor: orange, metallicness: brushed.metallicness, roughness: brushed.roughness)

struct ImportMaterialTests {
    @Test func `3MF import preserves per-triangle colors`() async throws {
        let exported = temporary3MFURL()
        let reexported = temporary3MFURL()
        defer {
            try? FileManager.default.removeItem(at: exported)
            try? FileManager.default.removeItem(at: reexported)
        }
        try await twoColoredBoxes.export3MF(to: exported)

        let imported = Import(model: exported)
        let importedMaterials = try await materials(of: imported)
        #expect(importedMaterials == [.init(baseColor: .red, properties: nil), .init(baseColor: .blue, properties: nil)])

        // Every colored face keeps its color: exporting the imported geometry again covers the
        // same area in each color as the original export did.
        try await imported.export3MF(to: reexported)
        let originalAreas = try colorAreas(in: exported)
        let roundTrippedAreas = try colorAreas(in: reexported)
        #expect(originalAreas[threeMFRed] ?? 0 ≈ coloredArea)
        #expect(originalAreas[threeMFBlue] ?? 0 ≈ coloredArea)
        #expect(roundTrippedAreas[threeMFRed] ?? 0 ≈ coloredArea)
        #expect(roundTrippedAreas[threeMFBlue] ?? 0 ≈ coloredArea)
    }

    @Test func `3MF import preserves metallic materials`() async throws {
        let url = temporary3MFURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try await Box(boxSize)
            .withMaterial(color: .green, metallicness: 0.7, roughness: 0.3, name: "Brass")
            .export3MF(to: url)

        let importedMaterials = try await materials(of: Import(model: url))
        let material = try #require(importedMaterials.first)
        #expect(importedMaterials.count == 1)
        #expect(material.name == "Brass")
        // 3MF stores colors as bytes, so a component that isn't a whole number of 255ths comes
        // back rounded.
        #expect(material.baseColor ≈ .green)
        let properties = try #require(material.physicalProperties)
        #expect(properties.metallicness ≈ 0.7)
        #expect(properties.roughness ≈ 0.3)
    }

    @Test func `a part's default material reaches the imported faces`() async throws {
        let url = temporary3MFURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try await Box(boxSize).inPart(Part("Tinted", color: .yellow)).export3MF(to: url)

        let importedMaterials = try await materials(of: Import(model: url))
        #expect(importedMaterials == [.plain(.yellow)])
    }

    @Test func `each part of a multi-model file resolves against its own model`() async throws {
        let url = temporary3MFURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Parts are written as separate model files, each with its own resources. A part's colors
        // have to be looked up in the file that part came from: the ids repeat across files, so
        // reading the wrong one silently yields the wrong colors.
        let spacing = boxSize * 2
        try await Box(boxSize)
            .colored(.red)
            .inPart(Part("First"))
            .adding {
                Box(boxSize)
                    .translated(x: spacing)
                    .colored(.blue)
                    .inPart(Part("Second"))
            }
            .export3MF(to: url)

        let importedMaterials = try await materials(of: Import(model: url))
        #expect(importedMaterials == [.init(baseColor: .red, properties: nil), .init(baseColor: .blue, properties: nil)])
    }

    @Test func `colored() after import replaces the imported materials`() async throws {
        let url = temporary3MFURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try await twoColoredBoxes.export3MF(to: url)

        let recolored = try await materials(of: Import(model: url).colored(.black))
        #expect(recolored == [.init(baseColor: .black, properties: nil)])
    }

    @Test func `withoutMaterials() after import discards the imported materials`() async throws {
        let url = temporary3MFURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try await twoColoredBoxes.export3MF(to: url)

        let cleared = try await materials(of: Import(model: url).withoutMaterials())
        #expect(cleared.isEmpty)
    }

    @Test func `Boolean operations keep imported colors on the surviving faces`() async throws {
        let exported = temporary3MFURL()
        let cut = temporary3MFURL()
        defer {
            try? FileManager.default.removeItem(at: exported)
            try? FileManager.default.removeItem(at: cut)
        }
        try await twoColoredBoxes.export3MF(to: exported)

        // A vertical hole straddling the seam removes surface from both colors and adds
        // uncolored faces of its own.
        let holeDiameter = boxSize * 0.4
        let overshoot = boxSize
        let drilled = Import(model: exported)
            .subtracting {
                Cylinder(diameter: holeDiameter, height: boxSize + overshoot * 2)
                    .translated(x: boxSize, y: boxSize / 2, z: -overshoot)
            }
        let drilledMaterials = try await materials(of: drilled)
        #expect(drilledMaterials == [.init(baseColor: .red, properties: nil), .init(baseColor: .blue, properties: nil)])

        try await drilled.export3MF(to: cut)
        let areas = try colorAreas(in: cut)
        let red = try #require(areas[threeMFRed])
        let blue = try #require(areas[threeMFBlue])
        #expect(red > 0 && red < coloredArea)
        #expect(blue > 0 && blue < coloredArea)
    }

    @Test func `import resolves base materials, color groups, multiproperties and object defaults`() async throws {
        // A unit cube whose triangles pick their properties in every way the format allows.
        let properties: [TriangleProperty] = [
            (nil, nil), (nil, nil), // bottom: inherits the object's base material
            (nil, nil), (nil, nil), // top: inherits the object's base material
            (.uniform(0), 2), (.uniform(0), 2), // front: red from the color group
            (.perVertex(1, 0, 0), 2), (.perVertex(1, 0, 0), 2), // back: per-vertex indices, the first of which is blue
            (.uniform(0), 3), (.uniform(0), 3), // left: multiproperties layering blue over the base material
            (.uniform(99), 2), (.uniform(99), 2), // right: an index the color group doesn't have
        ]
        let data = try await unitCubePackage(
            resources: steelResources + [
                ThreeMF.ColorGroup(id: 2, colors: [threeMFRed, threeMFBlue]),
                ThreeMF.Multiproperties(id: 3, propertyGroupIDs: [1, 2], multis: [[0, 1]]),
            ],
            objectProperty: PropertyReference(groupID: 1, index: 0),
            triangleProperties: properties
        )

        let result = try await Import(model: data).evaluationResult

        let blueSteel = Material(name: "Steel", baseColor: .blue, metallicness: brushed.metallicness, roughness: brushed.roughness)
        #expect(Set(result.materialMapping.values) == [
            steel,
            .init(baseColor: .red, properties: nil),
            .init(baseColor: .blue, properties: nil),
            blueSteel,
        ])

        // Each material gets its own original ID, and the faces with an unresolvable property
        // share one more that maps to nothing.
        let idsByTriangleCount = result.concrete.meshGL().originalIDs.mapValues(\.count)
        #expect(idsByTriangleCount.count == 5)
        #expect(idsByTriangleCount.values.allSatisfy { $0 == 2 || $0 == 4 })
        let unmappedIDs = Set(idsByTriangleCount.keys).subtracting(result.materialMapping.keys)
        #expect(unmappedIDs.count == 1)
        #expect(unmappedIDs.allSatisfy { idsByTriangleCount[$0] == 2 })
    }

    @Test func `multiproperties layers blend by their blend method`() async throws {
        // A half-transparent blue and an opaque lime, each layered over the steel: the first mixed,
        // the second multiplied. The materials extension gives both formulas. Lime keeps the two
        // apart: mixed in at full alpha it would replace the orange, multiplied it darkens it.
        let translucentBlue = ThreeMF.Color(red: 0, green: 0, blue: 255, alpha: 128)
        let blueAlpha = 128.0 / 255.0
        let lime = ThreeMF.Color(red: 128, green: 255, blue: 0)
        let data = try await unitCubePackage(
            resources: steelResources + [
                ThreeMF.ColorGroup(id: 2, colors: [translucentBlue, lime]),
                ThreeMF.Multiproperties(id: 3, propertyGroupIDs: [1, 2], blendMethods: [.mix], multis: [[0, 0]]),
                ThreeMF.Multiproperties(id: 6, propertyGroupIDs: [1, 2], blendMethods: [.multiply], multis: [[0, 1]]),
            ],
            triangleProperties: allFaces((.uniform(0), 3)).prefix(6) + allFaces((.uniform(0), 6)).suffix(6)
        )

        let materials = try await materials(of: Import(model: data)).sorted { $0.baseColor.blue > $1.baseColor.blue }
        #expect(materials.count == 2)

        let mixed = try #require(materials.first)
        #expect(mixed.name == "Steel")
        #expect(mixed.physicalProperties == steel.physicalProperties)
        #expect(mixed.baseColor ≈ Color(
            red: orange.red * (1 - blueAlpha),
            green: orange.green * (1 - blueAlpha),
            blue: blueAlpha,
            alpha: 1
        ))

        let multiplied = try #require(materials.last)
        #expect(multiplied.name == "Steel")
        #expect(multiplied.physicalProperties == steel.physicalProperties)
        #expect(multiplied.baseColor ≈ Color(
            red: orange.red * Color(lime).red,
            green: orange.green * Color(lime).green,
            blue: 0,
            alpha: 1
        ))
    }

    @Test func `composite materials mix the display colors of their base materials`() async throws {
        // Three parts red to one part blue, shown with its own display properties. A second
        // composite with no proportions at all can't be shown and yields no material.
        let polished = ThreeMF.Metallic(name: "Polished", metallicness: 1, roughness: 0)
        let data = try await unitCubePackage(
            resources: [
                ThreeMF.BaseMaterialGroup(id: 1, properties: [
                    .init(name: "Red", displayColor: threeMFRed),
                    .init(name: "Blue", displayColor: threeMFBlue),
                ]),
                ThreeMF.MetallicDisplayProperties(id: 8, metallics: [polished, polished]),
                ThreeMF.CompositeMaterialGroup(
                    id: 7, baseMaterialGroupID: 1, baseMaterialIndices: [0, 1], displayPropertiesID: 8,
                    composites: [[3, 1], [0, 0]]
                ),
            ],
            triangleProperties: allFaces((.uniform(0), 7)).prefix(6) + allFaces((.uniform(1), 7)).suffix(6)
        )

        let result = try await Import(model: data).evaluationResult
        let materials = Array(result.materialMapping.values)
        #expect(materials.count == 1)
        let composite = try #require(materials.first)
        #expect(composite.baseColor ≈ Color(red: 0.75, green: 0, blue: 0.25))
        #expect(composite.physicalProperties == .init(metallicness: 1, roughness: 0))

        let idsByTriangleCount = result.concrete.meshGL().originalIDs.mapValues(\.count)
        #expect(idsByTriangleCount.count == 2)
        #expect(Set(idsByTriangleCount.keys).subtracting(result.materialMapping.keys).count == 1)
    }
}
