import Foundation
import Manifold3D
internal import ThreeMF
internal import Zip
internal import Nodal
import CadovaLiveLinkCore
#if canImport(CadovaLiveLinkClient)
import CadovaLiveLinkClient
#endif

extension MeshGL: @retroactive @unchecked Sendable {}

struct ThreeMFDataProvider: OutputDataProvider {
    let result: BuildResult<D3>
    let options: ModelOptions

    /// Generated once per provider instance, i.e. once per `Model.build()` call, and used both for
    /// the LiveLink push and as the 3MF Production Extension's `<build p:UUID="...">` value written
    /// moments later, so a LiveLink consumer can recognize the two as the same save.
    let buildUUID = UUID()

    init(result: BuildResult<D3>, options: ModelOptions) {
        self.result = result
        self.options = options
    }

    let fileExtension = "3mf"

    /// A single resolved part: its evaluated geometry and materials, before conversion to any
    /// particular output shape (3MF resources or a LiveLink message).
    struct ResolvedPart {
        let part: Part
        let manifold: Manifold
        let materials: [Manifold.OriginalID: Material]
    }

    /// Evaluates every included part's geometry, deduplicated against `EvaluationContext`'s
    /// cache. Shared by both `write(to:context:)` (the 3MF path) and `pushToLiveLink` — calling
    /// this twice per `Model.build()` (once for each) re-evaluates the same nodes, which is a
    /// cache hit rather than recomputation.
    func resolvedParts(context: EvaluationContext) async throws -> [ResolvedPart] {
        var outputs = result.elements[PartCatalog.self].mergedOutputs
        let acceptedSemantics = options.includedPartSemantics(for: .threeMF)

        let name = options[ModelName.self].name ?? "Model"
        let mainPart = Part(name, semantic: .solid)
        outputs[mainPart] = result

        outputs = outputs.filter { acceptedSemantics.contains($0.key.semantic) && $0.value.node.isEmpty == false }

        return try await outputs.asyncCompactMap { part, result -> ResolvedPart? in
            let nodeResult = try await context.result(for: result.node)
            return ResolvedPart(part: part, manifold: nodeResult.concrete, materials: nodeResult.materialMapping)
        }
    }

    func pushToLiveLink(destination url: URL, context: EvaluationContext) async {
        #if canImport(CadovaLiveLinkClient)
        guard !LiveLinkSettings.isDisabled else { return }
        do {
            let parts = try await resolvedParts(context: context)
            guard !parts.isEmpty else { return }
            let message = LiveLinkMessage(
                buildUUID: buildUUID,
                path: url.path(percentEncoded: false),
                parts: parts.map(Self.liveLinkPart),
                metadata: options[Metadata.self].liveLinkMetadata
            )
            try await LiveLinkClient.push(message)
        } catch {
            logger.debug("LiveLink push skipped for \(url.path): \(error)")
        }
        #endif
    }

    fileprivate enum ResourceIDOffset: ResourceID, CaseIterable {
        case object = 1
        case mainColorGroup
        case metallicProperties
        case metallicColorGroup

        static var count: Int { allCases.last!.rawValue }
    }

    private func makeModel(for resolved: ResolvedPart, modelIndex: Int) async -> (ThreeMF.Model, Item) {
        let part = resolved.part
        let manifold = resolved.manifold
        let materials = resolved.materials

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

        // No item matrix: each part's mesh is written in world coordinates, so what the file says a
        // part's coordinates are is what they are. Peeling a top-level transform onto the item instead
        // saved a vertex pass and an occasional cache hit, and cost every reader of the archive the
        // ability to take the mesh at face value.
        var item = Item(objectID: object.id, partNumber: part.name)
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
        let modelsAndItems: [(model: ThreeMF.Model, item: ThreeMF.Item, triangleCount: Int)] = try await ContinuousClock().measure {
            let resolved = try await resolvedParts(context: context)
            return await resolved.enumerated().asyncMap { modelIndex, resolvedPart -> (ThreeMF.Model, ThreeMF.Item, Int) in
                let (model, item) = await makeModel(for: resolvedPart, modelIndex: modelIndex)
                return (model, item, resolvedPart.manifold.triangleCount)
            }
        } results: { duration, results in
            let triangleCount = results.map { $0.2 }.reduce(0, +)
            logger.debug("Built 3MF structures and meshes with \(triangleCount) triangles in \(duration)")
        }

        var uniqueIDs: Set<String> = []
        let metadata = options[Metadata.self].threeMFMetadata

        if modelsAndItems.count > 1 {
            let items = try modelsAndItems.enumerated().map(unpacked).map { index, model, item, _ in
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
            .sorted { ($0.partNumber ?? "").localizedStandardCompare($1.partNumber ?? "") == .orderedAscending }

            archive.model = ThreeMF.Model(
                unit: .millimeter,
                requiredExtensions: [.production],
                recommendedExtensions: [.materials],
                customNamespaces: ["c": CadovaNamespace.uri],
                metadata: metadata,
                build: ThreeMF.Build(items: items, uuid: buildUUID)
            )
        } else if modelsAndItems.count == 1 {
            var (model, item, _) = modelsAndItems[0]
            item.partNumber = item.partNumber?.simpleIdentifier

            archive.model = ThreeMF.Model(
                unit: .millimeter,
                recommendedExtensions: [.materials, .production],
                customNamespaces: ["c": CadovaNamespace.uri],
                metadata: metadata,
                resources: model.resources.resources,
                build: ThreeMF.Build(items: [item], uuid: buildUUID)
            )
        } else {
            logger.warning("Model contains no objects. Exporting an empty 3MF file.")
            archive.model = ThreeMF.Model(metadata: metadata)
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
