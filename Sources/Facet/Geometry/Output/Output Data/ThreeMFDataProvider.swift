import Foundation
import Manifold3D
import ThreeMF

struct ThreeMFDataProvider: OutputDataProvider {
    let output: Output3D

    let fileExtension = "3mf"

    func generateOutput() throws -> Data {
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

        var objectCount = 0

        for (outputIndex, item) in outputs.enumerated() {
            let output = item.value
            let identifier = item.key

            guard !output.primitive.isEmpty else { continue }

            let materialMapping = output.elements[MaterialMapping.self]
            let meshData = output.primitive.meshGL()
            let originalIDRanges = meshData.originalIDs

            let orderedMaterialMapping = Array(materialMapping?.mapping ?? [:])

            let originalIDToPropertyReference = Dictionary(uniqueKeysWithValues: orderedMaterialMapping.map { originalID, material -> (D3.Primitive.OriginalID, PropertyReference) in
                switch material.properties {
                case .none:
                    return (originalID, PropertyReference(groupID: mainColorGroup.id, index: mainColorGroup.addColor(material.baseColor.threeMFColor)))
                case .metallic (let metallicness, let roughness):
                    let name = material.name ?? "Metallic \(metallicProperties.metallics.count + 1)"
                    metallicProperties.addMetallic(.init(name: name, metallicness: metallicness, roughness: roughness))
                    return (originalID, PropertyReference(groupID: metallicColorGroup.id, index: metallicColorGroup.addColor(material.baseColor.threeMFColor)))

                case .specular (let color, let glossiness):
                    let name = material.name ?? "Specular \(specularProperties.speculars.count + 1)"
                    specularProperties.addSpecular(.init(name: name, specularColor: color.threeMFColor, glossiness: glossiness))
                    return (originalID, PropertyReference(groupID: specularColorGroup.id, index: specularColorGroup.addColor(material.baseColor.threeMFColor)))
                }
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

            let mesh = ThreeMF.Mesh(vertices: meshData.vertices.map(\.threeMFVector), triangles: triangles)
            let object = ThreeMF.Object(id: nextObjectID(), type: .model, name: identifier.name, content: .mesh(mesh))
            let item = ThreeMF.Item(objectID: object.id, printable: identifier.printable)

            objects.append(object)
            items.append(item)
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
            metadata.append(ThreeMF.Metadata(name: .application, value: "Facet - http://facetcad.org/"))
        }
        if !metadata.contains(where: { $0.name == .creationDate }) {
            metadata.append(ThreeMF.Metadata(name: .creationDate, value: dateFormatter.string(from: Date())))
        }

        let model = ThreeMF.Model(
            unit: .millimeter,
            recommendedExtensionPrefixes: [Extension.materials.prefix],
            metadata: metadata,
            resources: resources,
            buildItems: items
        )

        let writer = PackageWriter()
        writer.model = model
        return try writer.finalize()
    }
}

fileprivate extension PartIdentifier {
    var printable: Bool? {
        self == .highlight || self == .background ? false : nil
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
