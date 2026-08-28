import Foundation
import Manifold3D
internal import ThreeMF
internal import Zip
internal import Nodal
#if canImport(CadovaLiveLinkClient)
import CadovaLiveLinkCore
import CadovaLiveLinkClient
#endif

extension MeshGL: @retroactive @unchecked Sendable {}
extension PackageWriter: @retroactive @unchecked Sendable {}

struct ThreeMFDataProvider: OutputDataProvider {
    let result: BuildResult<D3>
    let options: ModelOptions
    let environment: EnvironmentValues

    /// Generated once per provider instance, i.e. once per `Model.build()` call, and used both for
    /// the LiveLink push and as the 3MF Production Extension's `<build p:UUID="...">` value written
    /// moments later, so a LiveLink consumer can recognize the two as the same save.
    let buildUUID = UUID()

    init(result: BuildResult<D3>, options: ModelOptions, environment: EnvironmentValues) {
        self.result = result
        self.options = options
        self.environment = environment
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
    ///
    /// Parts whose geometry evaluates to nothing (e.g. a subtraction that fully cancels) are
    /// dropped, so neither the 3MF file nor a LiveLink push ever carries an empty part.
    func resolvedParts(context: EvaluationContext) async throws -> [ResolvedPart] {
        var outputs = result.elements[PartCatalog.self].mergedOutputs
        let acceptedSemantics = options.includedPartSemantics(for: .threeMF)

        let name = options[ModelName.self].name ?? "Model"
        let mainPart = Part(name, semantic: .solid)
        outputs[mainPart] = result

        outputs = outputs.filter { acceptedSemantics.contains($0.key.semantic) && $0.value.node.isEmpty == false }

        return try await outputs.asyncCompactMap { part, result -> ResolvedPart? in
            let nodeResult = try await context.result(for: result.node)
            guard nodeResult.concrete.isEmpty == false else { return nil }
            return ResolvedPart(part: part, manifold: nodeResult.concrete, materials: nodeResult.materialMapping)
        }
    }

    /// Each part's file-facing identifier, matching exactly what `write(to:context:)` puts in each
    /// 3MF `<item partnumber="...">` — shared so a LiveLink push's part IDs agree with what ends up
    /// on disk moments later, letting a receiver key persistent per-part state (visibility,
    /// selection) on something that survives both paths.
    static func fileIdentifiers(for parts: [ResolvedPart]) -> [String] {
        var uniqueIDs: Set<String> = []
        return parts.map { resolved in
            let nameBase = resolved.part.name.simpleIdentifier
            var id = nameBase
            var suffix = 1
            while uniqueIDs.contains(id) {
                suffix += 1
                id = nameBase + "_\(suffix)"
            }
            uniqueIDs.insert(id)
            return id
        }
    }

    /// Whether `lhs` sorts before `rhs` as a file-facing identifier — the order `write(to:context:)`
    /// puts multi-part 3MF `<item>`s in, so a receiver's `Part.itemIndex` (used to address a specific
    /// build item when rewriting the archive, e.g. for slicing) means the same position in a LiveLink
    /// push as it will in the file moments later.
    static func fileOrder(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    func pushToLiveLink(destination url: URL, context: EvaluationContext) async {
        #if canImport(CadovaLiveLinkClient)
        // Mirrors the socket-existence check `LiveLinkClient.push` makes internally before sending,
        // so we only log success when a listener is actually present to receive the push.
        guard !LiveLinkSettings.isDisabled, FileManager.default.fileExists(atPath: LiveLinkEndpoint.socketPath) else { return }

        let path = url.path(percentEncoded: false)
        // Cheap, cached (read once per process — see LiveLinkClient.hostState) check for whether the
        // host is even watching this path before paying for geometry-to-wire conversion, which is
        // real, non-trivial CPU work for a large model that would otherwise happen unconditionally
        // for every model in a project regardless of what's actually open in the viewer.
        guard LiveLinkClient.isInterested(inPath: path) else {
            logger.debug("Skipped live link push for \(url.lastPathComponent): host isn't watching this path")
            return
        }

        do {
            let parts = try await resolvedParts(context: context)
            guard !parts.isEmpty else { return }
            let identifiers = Self.fileIdentifiers(for: parts)
            let orderedParts = zip(identifiers, parts).sorted { Self.fileOrder($0.0, $1.0) }
            let message = LiveLinkMessage(
                buildUUID: buildUUID,
                path: path,
                parts: orderedParts.map { Self.liveLinkPart(id: $0, $1) },
                metadata: options[Metadata.self].liveLinkMetadata
            )
            try await LiveLinkClient.push(message)
            logger.info("Pushed model \"\(url.lastPathComponent)\" to Cadova Viewer")
        } catch {
            logger.debug("Skipped live link push for \(url.lastPathComponent): \(error)")
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
        let resolved = try await resolvedParts(context: context)
        let identifiers = Self.fileIdentifiers(for: resolved)

        let modelsAndItems: [(part: Part, model: ThreeMF.Model, item: ThreeMF.Item, triangleCount: Int)] = await ContinuousClock().measure {
            await resolved.enumerated().asyncMap { modelIndex, resolvedPart -> (Part, ThreeMF.Model, ThreeMF.Item, Int) in
                let (model, item) = await makeModel(for: resolvedPart, modelIndex: modelIndex)
                return (resolvedPart.part, model, item, resolvedPart.manifold.triangleCount)
            }
        } results: { duration, results in
            let triangleCount = results.map { $0.3 }.reduce(0, +)
            logger.debug("Built 3MF structures and meshes with \(triangleCount) triangles in \(duration)")
        }

        let metadata = options[Metadata.self].threeMFMetadata

        if modelsAndItems.count > 1 {
            let items = try zip(identifiers, modelsAndItems).map { id, entry in
                var item = entry.item
                item.partNumber = id
                item.path = try archive.addAdditionalModel(entry.model, named: id)
                return item
            }
            .sorted { Self.fileOrder($0.partNumber ?? "", $1.partNumber ?? "") }

            archive.model = ThreeMF.Model(
                unit: .millimeter,
                requiredExtensions: [.production],
                recommendedExtensions: [.materials],
                customNamespaces: ["c": CadovaNamespace.uri],
                metadata: metadata,
                build: ThreeMF.Build(items: items, uuid: buildUUID)
            )
        } else if modelsAndItems.count == 1 {
            var (_, model, item, _) = modelsAndItems[0]
            item.partNumber = identifiers[0]

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

        try await runArchiveFinalizers(archive: archive, modelsAndItems: modelsAndItems, context: context)
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
        modelsAndItems: [(part: Part, model: ThreeMF.Model, item: ThreeMF.Item, triangleCount: Int)],
        context: EvaluationContext
    ) async throws {
        let finalizers = result.elements[ArchiveFinalizers.self].finalizers
        guard !finalizers.isEmpty else { return }

        let objectIDsByPart = Dictionary(uniqueKeysWithValues: modelsAndItems.map { ($0.part, $0.item.objectID) })
        // Finalizers can be registered redundantly from several places in a tree (see
        // `withArchiveFinalizer`'s doc comment), so track which paths have already been written
        // this export — added paths never disappear, so a plain set is enough even though finalizers
        // run sequentially, one export at a time.
        let addedPaths = AddedPathsTracker()
        let addFileHandler: @Sendable (String, String?, String?, Bool, Data) throws -> Void = {
            path, contentType, relationshipType, relativeToRootModel, data in
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
        }

        // Reads go straight to the writer, which serializes a model file on demand to satisfy one and
        // then leaves it staged — so a finalizer that reads the model, changes it and writes it back
        // gets its version into the archive rather than having it regenerated over the top.
        let contentsHandler: @Sendable (String) -> Data? = { path in
            guard let escapedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: escapedPath) else { return nil }
            return try? archive.fileContents(at: url)
        }

        for finalizer in finalizers.values {
            // Each finalizer gets its own evaluator: the evaluator stops reading after its first
            // failed read, so sharing one would silently turn every later finalizer's reads into
            // fallback values instead of surfacing the error.
            let evaluator = GeometryEvaluator(context: context, environment: environment)
            let archiveHandle = ModelArchive(
                rootGeometry: result,
                evaluator: evaluator,
                objectIDsByPart: objectIDsByPart,
                resultElements: result.elements,
                addFileHandler: addFileHandler,
                fileExistsHandler: { path in addedPaths.contains(path) },
                contentsHandler: contentsHandler
            )
            try await finalizer(archiveHandle)
            if let error = await evaluator.firstError {
                throw error
            }
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
