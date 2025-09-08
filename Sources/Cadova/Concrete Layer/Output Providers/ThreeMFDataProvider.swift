import Foundation
import Manifold3D
import ThreeMF
import Zip
import Nodal
import CadovaCPP

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

    fileprivate struct PartData {
        let id: PartIdentifier
        let manifold: Manifold
        let materials: [Manifold.OriginalID: Material]
    }

    private func makeModel(_ parts: [PartData]) async -> ThreeMF.Model {
        var nextFreeObjectID = 1

        func nextObjectID() -> Int {
            let id = nextFreeObjectID
            nextFreeObjectID += 1
            return id
        }

        var mainColorGroup = ColorGroup(id: nextObjectID())
        var metallicProperties = MetallicDisplayProperties(id: nextObjectID())
        var metallicColorGroup = ColorGroup(id: nextObjectID(), displayPropertiesID: metallicProperties.id)

        func addMaterial(_ material: Material) -> PropertyReference {
            .addMaterial(material, mainColorGroup: &mainColorGroup, metallicColorGroup: &metallicColorGroup, metallicProperties: &metallicProperties)
        }

        var uniqueIdentifiers: Set<String> = []

        struct PreparedPart {
            let id: PartIdentifier
            let vertices: [Vector3D]
            let triangleOIDs: TriangleOIDMapping
            let triangles: [Manifold3D.Triangle]
            let propertyReferencesByOID: [Manifold.OriginalID: PropertyReference]
            let defaultMaterial: PropertyReference
            let partNumber: String
            let objectID: Int
        }

        let preparedParts = parts.map { part in
            let (vertices, manifoldTriangles, originalIDs) = part.manifold.readMesh()

            let triangleOIDs = TriangleOIDMapping(indexSets: originalIDs)
            let propertyReferencesByOID = part.materials.mapValues(addMaterial)
            let defaultProperty = addMaterial(part.id.defaultMaterial)

            var uniqueID = part.id.name
            var nameIndex = 1
            while uniqueIdentifiers.contains(uniqueID) {
                nameIndex += 1
                uniqueID = part.id.name + "_\(nameIndex)"
            }
            uniqueIdentifiers.insert(uniqueID)

            return PreparedPart(
                id: part.id,
                vertices: vertices,
                triangleOIDs: triangleOIDs,
                triangles: manifoldTriangles,
                propertyReferencesByOID: propertyReferencesByOID,
                defaultMaterial: defaultProperty,
                partNumber: uniqueID,
                objectID: nextObjectID()
            )
        }

        let objectsAndItems = await preparedParts.asyncMap { preparedPart in
            let triangles = preparedPart.triangles.enumerated().map { index, t in
                let originalID = preparedPart.triangleOIDs.originalID(for: index)
                let materialProperty = originalID.flatMap { preparedPart.propertyReferencesByOID[$0] }

                return ThreeMF.Mesh.Triangle(
                    v1: Int(t.a), v2: Int(t.b), v3: Int(t.c),
                    propertyIndex: materialProperty.map { .uniform($0.index) },
                    propertyGroup: materialProperty?.groupID
                )
            }

            let mesh = ThreeMF.Mesh(vertices: preparedPart.vertices.map(\.threeMFVector), triangles: triangles)
            let object = ThreeMF.Object(
                id: preparedPart.objectID,
                type: .model,
                name: preparedPart.id.name,
                propertyGroupID: preparedPart.defaultMaterial.groupID,
                propertyIndex: preparedPart.defaultMaterial.index,
                content: .mesh(mesh)
            )

            let attributes: [ExpandedName: String] = [
                .printable: preparedPart.id.type == .solid ? "1" : "0",
                .semantic: preparedPart.id.type.xmlAttributeValue
            ]
            let item = Item(objectID: object.id, partNumber: preparedPart.partNumber, customAttributes: attributes)
            return (object: object, item: item)
        }

        var resources: [any ThreeMF.Resource] = []
        if !mainColorGroup.colors.isEmpty {
            resources.append(mainColorGroup)
        }

        if !metallicColorGroup.colors.isEmpty {
            resources.append(metallicProperties)
            resources.append(metallicColorGroup)
        }

        resources.append(contentsOf: objectsAndItems.map(\.object))

        if objectsAndItems.isEmpty {
            logger.warning("Model contains no objects. Exporting an empty 3MF file.")
        }

        return ThreeMF.Model(
            unit: .millimeter,
            recommendedExtensions: [.materials],
            customNamespaces: ["c": CadovaNamespace.uri],
            metadata: options[Metadata.self].threeMFMetadata,
            resources: resources,
            buildItems: objectsAndItems.map(\.item)
        )
    }

    private func makeModel(context: EvaluationContext) async throws -> ThreeMF.Model {
        var outputs = result.elements[PartCatalog.self].mergedOutputs
        let acceptedSemantics = options.includedPartSemantics(for: .threeMF)
        outputs[.main] = result
        outputs = outputs.filter { acceptedSemantics.contains($0.key.type) }

        let parts = try await ContinuousClock().measure {
            try await outputs.asyncCompactMap { partIdentifier, result -> PartData? in
                guard !result.node.isEmpty else { return nil }
                let nodeResult = try await context.result(for: result.node)

                return PartData(
                    id: partIdentifier,
                    manifold: nodeResult.concrete,
                    materials: nodeResult.materialMapping
                )
            }
            .sorted(using: [
                KeyPathComparator(\.id.name),
                KeyPathComparator(\.id.type.rawValue),
            ])

        } results: { duration, meshData in
            let triangleCount = meshData.map { $0.manifold.triangleCount }.reduce(0, +)
            logger.debug("Built meshes with \(triangleCount) triangles in \(duration)")
        }

        return await ContinuousClock().measure {
            await makeModel(parts)
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
}

fileprivate extension Color {
    var threeMFColor: ThreeMF.Color {
        ThreeMF.Color(
            red: UInt8(round(red * 255.0)),
            green: UInt8(round(green * 255.0)),
            blue: UInt8(round(blue * 255.0)),
            alpha: UInt8(round(alpha * 255.0))
        )
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
        let threeMFColor = baseColor.threeMFColor

        let index = properties.metallics.indices.first { index in
            properties.metallics[index] == metallic && colorGroup.colors[index] == threeMFColor
        } ?? {
            properties.addMetallic(metallic)
            return colorGroup.addColor(threeMFColor)
        }()

        return PropertyReference(groupID: colorGroup.id, index: index)
    }

    static func addSpecular(
        name: String?, baseColor: Color, specularColor: Color, glossiness: Double,
        to properties: inout SpecularDisplayProperties, colorGroup: inout ColorGroup
    ) -> PropertyReference {
        let name = name ?? "Specular \(properties.speculars.count + 1)"
        let specular = Specular(name: name, specularColor: specularColor.threeMFColor, glossiness: glossiness)
        let threeMFColor = baseColor.threeMFColor

        let index = properties.speculars.indices.first { index in
            properties.speculars[index] == specular && colorGroup.colors[index] == threeMFColor
        } ?? {
            properties.addSpecular(specular)
            return colorGroup.addColor(baseColor.threeMFColor)
        }()

        return PropertyReference(groupID: colorGroup.id, index: index)
    }

    static func addMaterial(
        _ material: Material,
        mainColorGroup: inout ColorGroup,
        metallicColorGroup: inout ColorGroup,
        metallicProperties: inout MetallicDisplayProperties
    ) -> PropertyReference {
        if let properties = material.physicalProperties {
            addMetallic(
                baseColor: material.baseColor,
                name: material.name,
                metallicness: properties.metallicness,
                roughness: properties.roughness,
                to: &metallicProperties,
                colorGroup: &metallicColorGroup
            )
        } else {
            addColor(material.baseColor, to: &mainColorGroup)
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

fileprivate extension ExpandedName {
    static let printable = ExpandedName(namespaceName: nil, localName: "printable")
    static let semantic = CadovaNamespace.semantic
}

fileprivate struct CadovaNamespace {
    static let uri = "https://cadova.org/3mf"
    static let semantic = ExpandedName(namespaceName: uri, localName: "semantic")
}

fileprivate extension PartSemantic {
    init?(xmlAttributeValue value: String) {
        self.init(rawValue: value)
    }

    var xmlAttributeValue: String { rawValue }
}
