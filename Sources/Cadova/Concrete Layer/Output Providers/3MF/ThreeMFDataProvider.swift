import Foundation
import Manifold3D
internal import ThreeMF
internal import Zip
internal import Nodal

extension MeshGL: @retroactive @unchecked Sendable {}
extension PackageWriter: @retroactive @unchecked Sendable {}

struct ThreeMFDataProvider: OutputDataProvider {
    let result: BuildResult<D3>
    let options: ModelOptions

    init(result: BuildResult<D3>, options: ModelOptions) {
        self.result = result
        self.options = options
    }

    let fileExtension = "3mf"

    fileprivate enum ResourceIDOffset: ResourceID, CaseIterable {
        case object = 1
        case mainColorGroup
        case metallicProperties
        case metallicColorGroup

        static var count: Int { allCases.last!.rawValue }
    }

    private func makeModel(
        for part: Part,
        modelIndex: Int,
        manifold: Manifold,
        materials: [Manifold.OriginalID: Material],
        transform: Transform3D?
    ) async -> (ThreeMF.Model, Item) {
        // BambuStudio does not properly handle objects with the same ID in different model files,
        // so assign unique IDs for each until that bug is fixed
        let startID = modelIndex * ResourceIDOffset.count
        var mainColorGroup = ColorGroup(id: startID + ResourceIDOffset.mainColorGroup.rawValue)
        var metallicProperties = MetallicDisplayProperties(id: startID + ResourceIDOffset.metallicProperties.rawValue)
        var metallicColorGroup = ColorGroup(id: startID + ResourceIDOffset.metallicColorGroup.rawValue, displayPropertiesID: metallicProperties.id)

        func addMaterial(_ material: Material) -> PropertyReference {
            .addMaterial(material, mainColorGroup: &mainColorGroup, metallicColorGroup: &metallicColorGroup, metallicProperties: &metallicProperties)
        }

        let meshGL = manifold.meshGL()
        let vertices = meshGL.vertices
        let manifoldTriangles = meshGL.triangles
        let originalIDs = meshGL.originalIDs

        let triangleOIDs = TriangleOIDMapping(indexSets: originalIDs)
        let propertyReferencesByOID = materials.mapValues(addMaterial)
        let defaultProperty = part.defaultMaterial.map(addMaterial)

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
            id: startID + ResourceIDOffset.object.rawValue,
            type: .model,
            name: part.name,
            propertyGroupID: defaultProperty?.groupID,
            propertyIndex: defaultProperty?.index,
            content: .mesh(mesh)
        )

        var item = Item(objectID: object.id, transform: transform?.matrix3D, partNumber: part.name)
        item.printable = part.semantic == .solid
        item.semantic = part.semantic

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

        let name = options[ModelName.self].name ?? "Model"
        let mainPart = Part(name, semantic: .solid)

        outputs[mainPart] = result
        outputs = outputs.filter { acceptedSemantics.contains($0.key.semantic) && $0.value.node.isEmpty == false }

        let modelsAndItems: [(part: Part, model: ThreeMF.Model, item: ThreeMF.Item, triangleCount: Int)] = try await ContinuousClock().measure {
            try await outputs.enumerated().asyncCompactMap { modelIndex, content -> (Part, ThreeMF.Model, ThreeMF.Item, Int)? in
                let (part, result) = content
                let (node, transform) = result.node.deconstructTransform()
                let nodeResult = try await context.result(for: node)
                let (model, item) = await makeModel(
                    for: part,
                    modelIndex: modelIndex,
                    manifold: nodeResult.concrete,
                    materials: nodeResult.materialMapping,
                    transform: transform
                )
                return (part, model, item, nodeResult.concrete.triangleCount)
            }
        } results: { duration, results in
            let triangleCount = results.map { $0.3 }.reduce(0, +)
            logger.debug("Built 3MF structures and meshes with \(triangleCount) triangles in \(duration)")
        }

        var uniqueIDs: Set<String> = []

        if modelsAndItems.count > 1 {
            let items = try modelsAndItems.enumerated().map { index, entry in
                let nameBase = entry.item.partNumber?.simpleIdentifier ?? "part-\(index)"
                var id = nameBase
                var nameIndex = 1
                while uniqueIDs.contains(id) {
                    nameIndex += 1
                    id = nameBase + "_\(nameIndex)"
                }
                uniqueIDs.insert(id)

                var item = entry.item
                item.partNumber = id
                item.path = try archive.addAdditionalModel(entry.model, named: id)
                return item
            }
            .sorted { ($0.partNumber ?? "").localizedStandardCompare($1.partNumber ?? "") == .orderedAscending }

            archive.model = ThreeMF.Model(
                unit: .millimeter,
                requiredExtensions: [.production],
                recommendedExtensions: [.materials],
                customNamespaces: ["c": CadovaNamespace.uri],
                metadata: options[Metadata.self].threeMFMetadata,
                buildItems: items
            )
        } else if modelsAndItems.count == 1 {
            let entry = modelsAndItems[0]
            var item = entry.item
            item.partNumber = item.partNumber?.simpleIdentifier

            archive.model = ThreeMF.Model(
                unit: .millimeter,
                recommendedExtensions: [.materials],
                customNamespaces: ["c": CadovaNamespace.uri],
                metadata: options[Metadata.self].threeMFMetadata,
                resources: entry.model.resources.resources,
                buildItems: [item]
            )
        } else {
            logger.warning("Model contains no objects. Exporting an empty 3MF file.")
            archive.model = ThreeMF.Model(metadata: options[Metadata.self].threeMFMetadata)
        }

        try await runArchiveFinalizers(archive: archive, modelsAndItems: modelsAndItems)
    }

    /// Tracks which archive paths have been written during one export. Finalizers run sequentially
    /// within a single `write()` call, never concurrently, so plain mutation is safe despite the
    /// `@unchecked Sendable` — this mirrors the same pattern already used for `PackageWriter` itself.
    private final class AddedPathsTracker: @unchecked Sendable {
        private var paths: Set<String> = []
        func insert(_ path: String) { paths.insert(path) }
        func contains(_ path: String) -> Bool { paths.contains(path) }
    }

    private func runArchiveFinalizers<T>(
        archive: PackageWriter<T>,
        modelsAndItems: [(part: Part, model: ThreeMF.Model, item: ThreeMF.Item, triangleCount: Int)]
    ) async throws {
        let finalizers = result.elements[ArchiveFinalizers.self].finalizers
        guard !finalizers.isEmpty else { return }

        let objectIDsByPart = Dictionary(uniqueKeysWithValues: modelsAndItems.map { ($0.part, $0.item.objectID) })
        // Finalizers can be registered redundantly from several places in a tree (see
        // `withArchiveFinalizer`'s doc comment), so track which paths have already been written
        // this export — added paths never disappear, so a plain set is enough even though finalizers
        // run sequentially, one export at a time.
        let addedPaths = AddedPathsTracker()
        let archiveHandle = ModelArchive(
            objectIDsByPart: objectIDsByPart,
            resultElements: result.elements,
            addFileHandler: { path, contentType, relationshipType, relativeToRootModel, data in
                guard let escapedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                      let url = URL(string: escapedPath) else {
                    throw ModelArchiveError.invalidArchivePath(path)
                }
                archive.addFile(
                    at: url,
                    contentType: contentType,
                    relationshipType: relationshipType,
                    relativeToRootModel: relativeToRootModel,
                    data: data
                )
                addedPaths.insert(path)
            },
            fileExistsHandler: { path in addedPaths.contains(path) }
        )
        for finalizer in finalizers.values {
            try finalizer(archiveHandle)
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
