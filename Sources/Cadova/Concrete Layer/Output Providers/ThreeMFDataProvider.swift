import Foundation
import Manifold3D
import ThreeMF
import Zip

extension MeshGL: @retroactive @unchecked Sendable {}

struct ThreeMFDataProvider: OutputDataProvider {
    let result: D3.BuildResult
    let options: ModelOptions

    init(result: D3.BuildResult, options: ModelOptions) {
        self.result = result
        self.options = options
    }

    init(result: D2.BuildResult, options: ModelOptions) {
        self.result = result.replacing(node: D3.Node.extrusion(result.node, type: .linear(height: 0.001)))
        self.options = options
    }

    let fileExtension = "3mf"

    private struct PartData {
        let id: PartIdentifier
        let mesh: MeshGL
        let materials: [Manifold.OriginalID: Material]
    }

    private func makeModel(_ parts: [PartData]) -> ThreeMF.Model {
        var nextFreeObjectID = 1

        func nextObjectID() -> Int {
            let id = nextFreeObjectID
            nextFreeObjectID += 1
            return id
        }

        var resources: [any ThreeMF.Resource] = []
        var objects: [Object] = []
        var items: [ThreeMF.Item] = []

        var mainColorGroup = ColorGroup(id: nextObjectID())

        var metallicProperties = MetallicDisplayProperties(id: nextObjectID())
        var metallicColorGroup = ColorGroup(id: nextObjectID(), displayPropertiesID: metallicProperties.id)

        var specularProperties = SpecularDisplayProperties(id: nextObjectID())
        var specularColorGroup = ColorGroup(id: nextObjectID(), displayPropertiesID: specularProperties.id)

        func addMaterial(_ material: Material) -> PropertyReference {
            .addMaterial(material, mainColorGroup: &mainColorGroup, metallicColorGroup: &metallicColorGroup, specularColorGroup: &specularColorGroup, metallicProperties: &metallicProperties, specularProperties: &specularProperties)
        }

        var objectCount = 0
        var uniqueIdentifiers: Set<String> = []

        for part in parts {
            let triangleOIDs = TriangleOIDMapping(indexSets: part.mesh.originalIDs)
            let propertyReferencesByOID = part.materials.mapValues(addMaterial)

            let triangles = part.mesh.triangles.enumerated().map { index, t in
                let originalID = triangleOIDs.originalID(for: index)
                let materialProperty = originalID.flatMap { propertyReferencesByOID[$0] }

                return ThreeMF.Mesh.Triangle(
                    v1: Int(t.a), v2: Int(t.b), v3: Int(t.c),
                    propertyIndex: materialProperty.map { .uniform($0.index) },
                    propertyGroup: materialProperty?.groupID
                )
            }

            let defaultProperty = addMaterial(part.id.defaultMaterial)

            let mesh = ThreeMF.Mesh(vertices: part.mesh.vertices.map(\.threeMFVector), triangles: triangles)
            let object = ThreeMF.Object(
                id: nextObjectID(),
                type: .model,
                name: part.id.name,
                propertyGroupID: defaultProperty.groupID,
                propertyIndex: defaultProperty.index,
                content: .mesh(mesh)
            )

            var uniqueID = part.id.name
            var nameIndex = 1
            while uniqueIdentifiers.contains(uniqueID) {
                nameIndex += 1
                uniqueID = part.id.name + "_\(nameIndex)"
            }
            uniqueIdentifiers.insert(uniqueID)

            objects.append(object)
            items.append(.init(objectID: object.id, partNumber: uniqueID, printable: part.id.type == .solid))
            objectCount += 1
        }

        if !mainColorGroup.colors.isEmpty {
            resources.append(mainColorGroup)
        }

        if !metallicColorGroup.colors.isEmpty {
            resources.append(metallicProperties)
            resources.append(metallicColorGroup)
        }

        if !specularColorGroup.colors.isEmpty {
            resources.append(specularProperties)
            resources.append(specularColorGroup)
        }

        resources.append(contentsOf: objects)

        if objectCount == 0 {
            logger.warning("Model contains no objects. Exporting an empty 3MF file.")
        }

        return ThreeMF.Model(
            unit: .millimeter,
            recommendedExtensions: [.materials],
            metadata: options[Metadata.self].threeMFMetadata,
            resources: resources,
            buildItems: items
        )
    }

    private func makeModel(context: EvaluationContext) async throws -> ThreeMF.Model {
        var outputs = result.elements[PartCatalog.self].mergedOutputs
        outputs[.main] = result

        let parts = await ContinuousClock().measure {
            await outputs.asyncCompactMap { partIdentifier, result -> PartData? in
                guard !result.node.isEmpty else { return nil }
                let nodeResult = await context.result(for: result.node)

                return PartData(
                    id: partIdentifier,
                    mesh: nodeResult.concrete.meshGL(),
                    materials: nodeResult.materialMapping
                )
            }
            .sorted(by: { $0.id.hashValue < $1.id.hashValue })
        } results: { duration, meshData in
            let triangleCount = meshData.map { $0.mesh.triangleCount }.reduce(0, +)
            logger.debug("Built meshes with \(triangleCount) triangles in \(duration)")
        }

        return await ContinuousClock().measure {
            makeModel(parts)
        } results: { duration, _ in
            logger.debug("Built 3MF structure in \(duration)")
        }
    }

    func generateOutput(context: EvaluationContext) async throws -> Data {
        let writer = PackageWriter()
        writer.compressionLevel = options[ModelOptions.Compression.self].zipCompression
        writer.model = try await makeModel(context: context)

        let data = try await ContinuousClock().measure {
            try writer.finalize()
        } results: { duration, _ in
            logger.debug("Generated 3MF archive in \(duration)")
        }

        return data
    }

    func writeOutput(to url: URL, context: EvaluationContext) async throws {
        let writer = try PackageWriter(url: url)
        writer.compressionLevel = options[ModelOptions.Compression.self].zipCompression
        writer.model = try await makeModel(context: context)
        let duration = try ContinuousClock().measure {
            try writer.finalize()
        }
        logger.debug("Generated 3MF archive in \(duration)")
    }
}

fileprivate extension Color {
    var threeMFColor: ThreeMF.Color {
        ThreeMF.Color(red: UInt8(round(red * 255.0)), green: UInt8(round(green * 255.0)), blue: UInt8(round(blue * 255.0)), alpha: UInt8(round(alpha * 255.0)))
    }
}

fileprivate extension Manifold3D.Vector3 {
    var threeMFVector: ThreeMF.Mesh.Vertex {
        .init(x: Double(x), y: Double(y), z: Double(z))
    }
}

struct TriangleOIDMapping {
    private typealias Entry = (range: Range<Int>, originalID: Manifold.OriginalID)
    private let sortedEntries: [Entry]

    init(indexSets: [Manifold.OriginalID: IndexSet]) {
        var entries: [Entry] = []
        for (originalID, indexSet) in indexSets {
            for range in indexSet.rangeView {
                entries.append((range, originalID))
            }
        }
        entries.sort(by: { $0.range.lowerBound < $1.range.lowerBound })
        self.sortedEntries = entries
    }

    func originalID(for triangleIndex: Int) -> Manifold.OriginalID? {
        for (range, originalID) in sortedEntries {
            if range.lowerBound > triangleIndex {
                return nil
            }
            if range.upperBound > triangleIndex {
                return originalID
            }
        }
        return nil
    }
}

extension PropertyReference {
    static func addColor(_ color: Color, to colorGroup: inout ColorGroup) -> PropertyReference {
        let threeMFColor = color.threeMFColor
        if let index = colorGroup.colors.firstIndex(of: threeMFColor) {
            return PropertyReference(groupID: colorGroup.id, index: index)
        } else {
            let index = colorGroup.addColor(threeMFColor)
            return PropertyReference(groupID: colorGroup.id, index: index)
        }
    }

    static func addMetallic(
        baseColor: Color, name: String?, metallicness: Double, roughness: Double,
        to properties: inout MetallicDisplayProperties, colorGroup: inout ColorGroup
    ) -> PropertyReference {
        let name = name ?? "Metallic \(properties.metallics.count + 1)"
        let metallic = Metallic(name: name, metallicness: metallicness, roughness: roughness)
        let index = properties.metallics.firstIndex(of: metallic) ?? {
            properties.addMetallic(metallic)
            return colorGroup.addColor(baseColor.threeMFColor)
        }()
        return PropertyReference(groupID: colorGroup.id, index: index)
    }

    static func addSpecular(
        name: String?, baseColor: Color, specularColor: Color, glossiness: Double,
        to properties: inout SpecularDisplayProperties, colorGroup: inout ColorGroup
    ) -> PropertyReference {
        let name = name ?? "Specular \(properties.speculars.count + 1)"
        let specular = Specular(name: name, specularColor: specularColor.threeMFColor, glossiness: glossiness)
        let index = properties.speculars.firstIndex(of: specular) ?? {
            properties.addSpecular(specular)
            return colorGroup.addColor(baseColor.threeMFColor)
        }()
        return PropertyReference(groupID: colorGroup.id, index: index)
    }

    static func addMaterial(
        _ material: Material,
        mainColorGroup: inout ColorGroup, metallicColorGroup: inout ColorGroup, specularColorGroup: inout ColorGroup,
        metallicProperties: inout MetallicDisplayProperties, specularProperties: inout SpecularDisplayProperties
    ) -> PropertyReference {
        switch material.properties {
        case .none:
            return addColor(material.baseColor, to: &mainColorGroup)

        case .metallic (let metallicness, let roughness):
            return addMetallic(baseColor: material.baseColor, name: material.name, metallicness: metallicness, roughness: roughness, to: &metallicProperties, colorGroup: &metallicColorGroup)

        case .specular (let color, let glossiness):
            return addSpecular(name: material.name, baseColor: material.baseColor, specularColor: color, glossiness: glossiness, to: &specularProperties, colorGroup: &specularColorGroup)
        }
    }
}

extension Metadata {
    var threeMFMetadata: [ThreeMF.Metadata] {
        [
            title.map { .init(name: .title, value: $0) },
            description.map { .init(name: .description, value: $0) },
            author.map { .init(name: .designer, value: $0) },
            license.map { .init(name: .licenseTerms, value: $0) },
            date.map { .init(name: .creationDate, value: $0) },
            application.map { .init(name: .application, value: $0) }
        ].compactMap { $0 }
    }
}

extension ModelOptions.Compression {
    var zipCompression: Zip.CompressionLevel {
        switch self {
        case .standard: return .default
        case .fastest: return .fastest
        case .smallest: return .best
        }
    }
}
