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

    fileprivate enum StaticResourceID: ResourceID {
        case object = 1
        case mainColorGroup
        case metallicProperties
        case metallicColorGroup
    }

    private func makeModel(_ part: PartData) async -> (ThreeMF.Model, Item) {
        var mainColorGroup = ColorGroup(id: StaticResourceID.mainColorGroup.rawValue)
        var metallicProperties = MetallicDisplayProperties(id: StaticResourceID.metallicProperties.rawValue)
        var metallicColorGroup = ColorGroup(id: StaticResourceID.metallicColorGroup.rawValue, displayPropertiesID: metallicProperties.id)

        func addMaterial(_ material: Material) -> PropertyReference {
            .addMaterial(material, mainColorGroup: &mainColorGroup, metallicColorGroup: &metallicColorGroup, metallicProperties: &metallicProperties)
        }

        let (vertices, manifoldTriangles, originalIDs) = part.manifold.readMesh()

        let triangleOIDs = TriangleOIDMapping(indexSets: originalIDs)
        let propertyReferencesByOID = part.materials.mapValues(addMaterial)
        let defaultProperty = addMaterial(part.id.defaultMaterial)

        let triangles = manifoldTriangles.enumerated().map { index, t in
            let originalID = triangleOIDs.originalID(for: index)
            let materialProperty = originalID.flatMap { propertyReferencesByOID[$0] }

            return ThreeMF.Mesh.Triangle(
                v1: Int(t.a), v2: Int(t.b), v3: Int(t.c),
                propertyIndex: materialProperty.map { .uniform($0.index) },
                propertyGroup: materialProperty?.groupID
            )
        }

        let mesh = ThreeMF.Mesh(vertices: vertices.map(\.threeMFVector), triangles: triangles)
        let object = ThreeMF.Object(
            id: StaticResourceID.object.rawValue,
            type: .model,
            name: part.id.name,
            propertyGroupID: defaultProperty.groupID,
            propertyIndex: defaultProperty.index,
            content: .mesh(mesh)
        )

        var item = Item(objectID: object.id, partNumber: part.id.name)
        item.printable = part.id.type == .solid
        item.semantic = part.id.type

        var resources: [any ThreeMF.Resource] = [object]
        if !mainColorGroup.colors.isEmpty {
            resources.append(mainColorGroup)
        }

        if !metallicColorGroup.colors.isEmpty {
            resources.append(metallicProperties)
            resources.append(metallicColorGroup)
        }

        let model = ThreeMF.Model(unit: .millimeter, recommendedExtensions: [.materials], resources: resources)
        return (model, item)
    }

    private func write<T>(to archive: PackageWriter<T>, context: EvaluationContext) async throws {
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

        try await ContinuousClock().measure {
            var uniqueIDs: Set<String> = []
            let modelsAndItems = await parts.asyncMap { await makeModel($0) }

            if modelsAndItems.count > 1 {
                let items = try modelsAndItems.enumerated().map(unpacked).map { index, model, item in
                    let nameBase = item.partNumber?.simpleIdentifier ?? "part-\(index)"
                    var id = nameBase
                    var nameIndex = 1
                    while uniqueIDs.contains(id) {
                        nameIndex += 1
                        id = nameBase + "_\(nameIndex)"
                    }
                    uniqueIDs.insert(id)

                    var item = item
                    item.partNumber = id
                    item.path = try archive.addAdditionalModel(model, named: id)
                    return item
                }

                archive.model = ThreeMF.Model(
                    unit: .millimeter,
                    requiredExtensions: [.production],
                    recommendedExtensions: [.materials],
                    customNamespaces: ["c": CadovaNamespace.uri],
                    metadata: options[Metadata.self].threeMFMetadata,
                    buildItems: items
                )
            } else if modelsAndItems.count == 1 {
                var (model, item) = modelsAndItems[0]
                item.partNumber = item.partNumber?.simpleIdentifier

                archive.model = ThreeMF.Model(
                    unit: .millimeter,
                    recommendedExtensions: [.materials],
                    customNamespaces: ["c": CadovaNamespace.uri],
                    metadata: options[Metadata.self].threeMFMetadata,
                    resources: model.resources.resources,
                    buildItems: [item]
                )
            } else {
                logger.warning("Model contains no objects. Exporting an empty 3MF file.")
                archive.model = ThreeMF.Model(metadata: options[Metadata.self].threeMFMetadata)
            }
        } results: { duration, _ in
            logger.debug("Built 3MF structure in \(duration)")
        }
    }

    func generateOutput(context: EvaluationContext) async throws -> Data {
        let archive = PackageWriter()
        archive.compressionLevel = options[ModelOptions.Compression.self].zipCompression
        try await write(to: archive, context: context)

        let data = try await ContinuousClock().measure {
            try await archive.finalize()
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
    static let semantic = CadovaNamespace.semantic
    // Prusa (?) extension
    static let printable = ExpandedName(namespaceName: nil, localName: "printable")
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

fileprivate extension ThreeMF.Item {
    var printable: Bool? {
        get {
            customAttributes[.printable].flatMap { try? Bool(xmlStringValue: $0) }
        }
        set {
            customAttributes[.printable] = newValue.map { $0 ? "1" : "0" }
        }
    }

    var semantic: PartSemantic? {
        get {
            customAttributes[.semantic].flatMap(PartSemantic.init(xmlAttributeValue:))
        }
        set {
            customAttributes[.semantic] = newValue?.xmlAttributeValue
        }
    }
}
