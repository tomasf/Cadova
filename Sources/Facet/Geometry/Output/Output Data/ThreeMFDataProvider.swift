import Foundation
import Manifold
import Zip

struct ThreeMFDataProvider: OutputDataProvider {
    let output: Output3D

    let fileExtension = "3mf"

    func generateOutput() throws -> Data {
        var outputs = output.elements[PartCatalog.self]?.mergedOutputs ?? [:]
        outputs[.main] = output

        var objects: [ThreeMF.Object] = []
        var items: [ThreeMF.Item] = []
        var colorGroups: [ThreeMF.ColorGroup] = []

        for (outputIndex, item) in outputs.enumerated() {
            let output = item.value
            let identifier = item.key

            guard !output.primitive.isEmpty else { continue }

            let colorMapping = output.elements[ColorMapping.self]
            let meshData = output.primitive.meshGL()
            let originalIDRanges = meshData.originalIDs

            let orderedColorMapping = Array(colorMapping?.mapping ?? [:])
            let colorGroup = ThreeMF.ColorGroup(id: outputIndex + 1, colors: orderedColorMapping.map(\.value))
            let colorIndexByOriginalID = Dictionary(orderedColorMapping.enumerated().map { ($1.key, $0) }, uniquingKeysWith: { $1 })

            let triangles = meshData.triangles.enumerated().map { index, t in
                let color = originalIDRanges.key(for: index)
                    .flatMap { colorIndexByOriginalID[$0] }
                    .flatMap { (group: colorGroup.id, colorIndex: $0) }

                return ThreeMF.Mesh.Triangle(v1: Int(t.a), v2: Int(t.b), v3: Int(t.c), color: color)
            }

            let mesh = ThreeMF.Mesh(vertices: meshData.vertices.map(\.vector3D), triangles: triangles)
            let object = ThreeMF.Object(id: outputIndex + 1, type: "model", name: identifier.name, mesh: mesh)
            let item = ThreeMF.Item(objectID: object.id, printable: identifier.printable)

            objects.append(object)
            items.append(item)
            colorGroups.append(colorGroup)
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

        let threeMF = ThreeMF(objects: objects, items: items, colorGroups: colorGroups, metadata: metadata)
        return try threeMF.generateData()
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
