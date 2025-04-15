import Foundation
import Manifold3D
import ThreeMF

struct ThreeMFDataProvider: OutputDataProvider {
    let output: Output3D

    let fileExtension = "3mf"

    func makeModel() throws -> ThreeMF.Model {
        var outputs = output.elements[PartCatalog.self]?.mergedOutputs ?? [:]
        outputs[.main] = output

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
            guard !output.primitive.isEmpty else { continue }

            let materialMapping = output.elements[MaterialMapping.self]
            let meshData = output.primitive.meshGL()
            let originalIDRanges = meshData.originalIDs

            let orderedMaterialMapping = Array(materialMapping?.mapping ?? [:])

            let originalIDToPropertyReference = Dictionary(uniqueKeysWithValues: orderedMaterialMapping.map { originalID, material in
                (originalID, addMaterial(material))
            })

            let triangles = meshData.triangles.enumerated().map { index, t in
                let originalID = originalIDRanges.key(for: index)
                let materialProperty = originalID.flatMap { originalIDToPropertyReference[$0] }

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

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        var metadata = output.elements[MetadataContainer.self]?.metadata ?? []
        if !metadata.contains(where: { $0.name == .application }) {
            metadata.append(ThreeMF.Metadata(name: .application, value: "Cadova - http://cadova.org/"))
        }
        if !metadata.contains(where: { $0.name == .creationDate }) {
            metadata.append(ThreeMF.Metadata(name: .creationDate, value: dateFormatter.string(from: Date())))
        }

        return ThreeMF.Model(
            unit: .millimeter,
            recommendedExtensions: [.materials],
            metadata: metadata,
            resources: resources,
            buildItems: items
        )
    }

    func generateOutput() throws -> Data {
        let startTime = CFAbsoluteTimeGetCurrent()

        let writer = PackageWriter()
        writer.model = try makeModel()
        let data = try writer.finalize()

        let finishTime = CFAbsoluteTimeGetCurrent()
        print(String(format: "Generated 3MF archive in %g seconds", finishTime - startTime))

        return data
    }

    func writeOutput(to url: URL) throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        let writer = try PackageWriter(url: url)
        writer.model = try makeModel()
        try writer.finalize()

        let finishTime = CFAbsoluteTimeGetCurrent()
        print(String(format: "Generated 3MF archive in %g seconds", finishTime - startTime))
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
