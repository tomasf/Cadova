import Foundation
import Manifold
import ThreeMF

struct ThreeMFDataProvider: OutputDataProvider {
    let output: Output3D

    let fileExtension = "3mf"

    func generateOutput() throws -> Data {
        var outputs = output.elements[PartCatalog.self]?.mergedOutputs ?? [:]
        outputs[.main] = output

        var objects: [ThreeMF.Object] = []
        var items: [ThreeMF.Item] = []
        var colorGroups: [ThreeMF.ColorGroup] = []
        var nextFreeObjectID = 1
        func nextObjectID() -> Int {
            let id = nextFreeObjectID
            nextFreeObjectID += 1
            return id
        }

        for (outputIndex, item) in outputs.enumerated() {
            let output = item.value
            let identifier = item.key

            guard !output.primitive.isEmpty else { continue }

            let colorMapping = output.elements[ColorMapping.self]
            let meshData = output.primitive.meshGL()
            let originalIDRanges = meshData.originalIDs

            let orderedColorMapping = Array(colorMapping?.mapping ?? [:])

            let colorGroup = ColorGroup(id: nextObjectID(), colors: orderedColorMapping.map(\.value.threeMFColor))
            let colorIndexByOriginalID = Dictionary(orderedColorMapping.enumerated().map { ($1.key, $0) }, uniquingKeysWith: { $1 })

            let triangles = meshData.triangles.enumerated().map { index, t in
                let colorIndex = originalIDRanges.key(for: index).flatMap { colorIndexByOriginalID[$0] }
                return ThreeMF.Mesh.Triangle(
                    v1: Int(t.a), v2: Int(t.b), v3: Int(t.c),
                    propertyIndex: colorIndex.map { .uniform($0) },
                    propertyGroup: colorIndex != nil ? colorGroup.id : nil
                )
            }

            let mesh = ThreeMF.Mesh(vertices: meshData.vertices.map(\.threeMFVector), triangles: triangles)
            let object = ThreeMF.Object(id: nextObjectID(), type: .model, name: identifier.name, content: .mesh(mesh))
            let item = ThreeMF.Item(objectID: object.id, printable: identifier.printable)

            objects.append(object)
            items.append(item)
            colorGroups.append(colorGroup)
        }

        if objects.isEmpty {
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
            resources: objects + colorGroups,
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

fileprivate extension Manifold.Vector3 {
    var threeMFVector: ThreeMF.Mesh.Vertex {
        .init(x: Double(x), y: Double(y), z: Double(z))
    }
}
