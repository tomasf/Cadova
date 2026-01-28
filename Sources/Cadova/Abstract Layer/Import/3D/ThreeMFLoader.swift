import Foundation
internal import ThreeMF

/// Loads 3MF files into mesh data.
internal struct ThreeMFLoader<T: Sendable> {
    let loader: ModelLoader<T>
    let parts: [Import<D3>.PartIdentifier]?

    init(url: URL, parts: [Import<D3>.PartIdentifier]?) where T == URL {
        self.loader = ModelLoader(url: url)
        self.parts = parts
    }

    init(data: Data, parts: [Import<D3>.PartIdentifier]?) where T == Data {
        self.loader = ModelLoader(data: data)
        self.parts = parts
    }

    func load() async throws -> D3.Node {
        let loadedModel = try await loader.load()
        let loadedItems = try loadedModel.loadedItems(for: parts)
        return D3.Node.boolean(loadedItems.map {
            $0.buildNode(model: loadedModel)
        }, type: .union)
    }
}

internal extension ModelLoader.LoadedModel {
    func loadedItems(for identifiers: [Import<D3>.PartIdentifier]?) throws -> [LoadedItem] {
        var remainingItems = items
        guard let identifiers else { return remainingItems }

        return try identifiers.map { identifier in
            guard let itemIndex = remainingItems.firstIndex(where: { $0.matches(identifier) }) else {
                throw Import<D3>.ModelError.missingPart(identifier)
            }
            return remainingItems.remove(at: itemIndex)
        }
    }
}

internal extension ModelLoader.LoadedModel.LoadedItem {
    func matches(_ identifier: Import<D3>.PartIdentifier) -> Bool {
        switch identifier {
        case .name (let name): rootObject.name == name
        case .partNumber (let partNumber): item.partNumber == partNumber
        }
    }

    func buildNode(model: ModelLoader.LoadedModel) -> D3.Node {
        .boolean(components.map { $0.buildNode(model: model) }, type: .union)
    }
}

internal extension ModelLoader.LoadedModel.LoadedComponent {
    func buildNode(model: ModelLoader.LoadedModel) -> D3.Node {
        let meshNode = D3.Node.shape(.mesh(MeshData(model.meshes[meshIndex].mesh)))
        return if let transform = cadovaTransform {
            .transform(meshNode, transform: transform)
        } else {
            meshNode
        }
    }

    var cadovaTransform: Transform3D? {
        guard !transforms.isEmpty else { return nil }
        return transforms.map(\.cadovaTransform)
            .reduce(Transform3D.identity) { $0.concatenated(with: $1) }
    }
}

internal extension MeshData {
    init(_ mesh: ThreeMF.Mesh) {
        self.init(
            vertices: mesh.vertices.map { Vector3D($0.x, $0.y, $0.z) },
            faces: mesh.triangles.map { [$0.v1, $0.v2, $0.v3] }
        )
    }
}

internal extension ThreeMF.Matrix3D {
    var cadovaTransform: Transform3D {
        Transform3D([
            [values[0][0], values[1][0], values[2][0], values[3][0]],
            [values[0][1], values[1][1], values[2][1], values[3][1]],
            [values[0][2], values[1][2], values[2][2], values[3][2]],
            [0, 0, 0, 1]
        ])
    }
}
