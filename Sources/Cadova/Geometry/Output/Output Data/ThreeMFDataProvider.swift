import Foundation
import Manifold3D
import ThreeMF

struct ThreeMFDataProvider: OutputDataProvider {
    let result: GeometryResult3D
    let fileExtension = "3mf"

    func makeModel(context: EvaluationContext) async throws -> ThreeMF.Model {
        var outputs = result.elements[PartCatalog.self].mergedOutputs
        outputs[.main] = result

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
            switch material.properties {
            case .none:
                let index = mainColorGroup.colors.firstIndex(of: material.baseColor.threeMFColor) ?? mainColorGroup.addColor(material.baseColor.threeMFColor)
                return PropertyReference(groupID: mainColorGroup.id, index: index)

            case .metallic (let metallicness, let roughness):
                let name = material.name ?? "Metallic \(metallicProperties.metallics.count + 1)"
                let metallic = Metallic(name: name, metallicness: metallicness, roughness: roughness)
                let index = metallicProperties.metallics.firstIndex(of: metallic) ?? {
                    metallicProperties.addMetallic(metallic)
                    return metallicColorGroup.addColor(material.baseColor.threeMFColor)
                }()
                return PropertyReference(groupID: metallicColorGroup.id, index: index)

            case .specular (let color, let glossiness):
                let name = material.name ?? "Specular \(specularProperties.speculars.count + 1)"
                let specular = Specular(name: name, specularColor: color.threeMFColor, glossiness: glossiness)
                let index = specularProperties.speculars.firstIndex(of: specular) ?? {
                    specularProperties.addSpecular(specular)
                    return specularColorGroup.addColor(material.baseColor.threeMFColor)
                }()
                return PropertyReference(groupID: specularColorGroup.id, index: index)
            }
        }

        var objectCount = 0
        var uniqueIdentifiers: Set<String> = []

        for (identifier, output) in outputs.sorted(by: { $0.key.hashValue < $1.key.hashValue }) {
            guard !output.expression.isEmpty else { continue }

            let meshData = await context.geometry(for: output.expression).meshGL()
            let triangleOIDs = TriangleOIDMapping(indexSets: meshData.originalIDs)

            let propertyReferencesByOID = await output.elements[MaterialRecord.self]
                .originalIDMapping(from: context)
                .mapValues(addMaterial)

            let triangles = meshData.triangles.enumerated().map { index, t in
                let originalID = triangleOIDs.originalID(for: index)
                let materialProperty = originalID.flatMap { propertyReferencesByOID[$0] }

                return ThreeMF.Mesh.Triangle(
                    v1: Int(t.a), v2: Int(t.b), v3: Int(t.c),
                    propertyIndex: materialProperty.map { .uniform($0.index) },
                    propertyGroup: materialProperty?.groupID
                )
            }

            let defaultProperty = addMaterial(identifier.defaultMaterial)

            let mesh = ThreeMF.Mesh(vertices: meshData.vertices.map(\.threeMFVector), triangles: triangles)
            let object = ThreeMF.Object(
                id: nextObjectID(),
                type: .model,
                name: identifier.name,
                propertyGroupID: defaultProperty.groupID,
                propertyIndex: defaultProperty.index,
                content: .mesh(mesh)
            )

            var uniqueID = identifier.name
            var nameIndex = 1
            while uniqueIdentifiers.contains(uniqueID) {
                nameIndex += 1
                uniqueID = identifier.name + "_\(nameIndex)"
            }
            uniqueIdentifiers.insert(uniqueID)

            objects.append(object)
            items.append(.init(objectID: object.id, partNumber: uniqueID, printable: identifier.printable))
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
            metadata: prepareMetadata(),
            resources: resources,
            buildItems: items
        )
    }

    private func prepareMetadata() -> [ThreeMF.Metadata] {
        var metadata = result.elements[MetadataContainer.self]

        if !metadata.contains(.application) {
            metadata.add(.application, value: "Cadova - http://cadova.org/")
        }
        if !metadata.contains(.creationDate) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            metadata.add(.creationDate, value: dateFormatter.string(from: Date()))
        }
        return metadata.metadata
    }

    func generateOutput(context: EvaluationContext) async throws -> Data {
        var data: Data = Data()
        let duration = try await ContinuousClock().measure {
            let writer = PackageWriter()
            writer.model = try await makeModel(context: context)
            data = try writer.finalize()
        }

        print(String(format: "Generated 3MF archive in %@", duration.formatted()))
        return data
    }

    func writeOutput(to url: URL, context: EvaluationContext) async throws {
        let duration = try await ContinuousClock().measure {
            let writer = try PackageWriter(url: url)
            writer.model = try await makeModel(context: context)
            try writer.finalize()
        }

        print(String(format: "Generated 3MF archive \(url.lastPathComponent) in %@", duration.formatted()))
    }
}

fileprivate extension PartIdentifier {
    var printable: Bool? {
        type == .solid
    }
}

fileprivate extension Dictionary where Value == IndexSet {
    func key(for index: IndexSet.Element) -> Key? {
        first(where: { $0.value.contains(index) })?.key
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
