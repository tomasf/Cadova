import Foundation
internal import ThreeMF

/// Loads 3MF files into mesh data.
internal struct ThreeMFLoader<T: Sendable> {
    let source: T
    let parts: [Import<D3>.PartIdentifier]?

    init(url: URL, parts: [Import<D3>.PartIdentifier]?) where T == URL {
        self.source = url
        self.parts = parts
    }

    init(data: Data, parts: [Import<D3>.PartIdentifier]?) where T == Data {
        self.source = data
        self.parts = parts
    }

    private func node(from loadedModel: ModelLoader<T>.LoadedModel) throws -> D3.Node {
        .boolean(try loadedModel.loadedItems(for: parts).map { $0.buildNode(model: loadedModel) }, type: .union)
    }
}

internal extension ThreeMFLoader where T == URL {
    func load(context: EvaluationContext) async throws -> D3.Node {
        try node(from: try await context.threeMFModelCache.loadedModel(url: source))
    }
}

internal extension ThreeMFLoader where T == Data {
    func load(context: EvaluationContext) async throws -> D3.Node {
        try node(from: try await context.threeMFModelCache.loadedModel(data: source))
    }
}

internal extension ModelLoader.LoadedModel {
    /// Returns the items to import: all of them when `identifiers` is `nil`, or one item per
    /// identifier otherwise. An item can't be matched twice. Throws `.missingPart` on the first
    /// identifier with no match.
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

internal extension Import<D3>.ModelPart {
    init(item: ModelLoader<some Sendable>.LoadedModel.LoadedItem, index: Int) {
        self.init(
            index: index,
            name: item.rootObject.name.flatMap { $0.isEmpty ? nil : $0 },
            partNumber: item.item.partNumber.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

internal extension ModelLoader.LoadedModel.LoadedComponent {
    func buildNode(model: ModelLoader.LoadedModel) -> D3.Node {
        let loadedMesh = model.meshes[meshIndex]
        // A property names a resource of the model file the mesh lives in: the object's own, or one
        // inherited from a parent in the same file. The loader stops inherited properties at a
        // file boundary, since ids mean nothing in another file (tomasf/ThreeMF#3).
        let meshNode = D3.Node.shape(.mesh(MeshData(loadedMesh.mesh, objectProperty: objectProperty) {
            model.material(for: $0, inModel: loadedMesh.modelIndex)
        }))
        return if let transform = cadovaTransform {
            .transform(meshNode, transform: transform)
        } else {
            meshNode
        }
    }

    /// The property the object gives its triangles, for those that don't name one of their own.
    var objectProperty: PropertyReference? {
        guard let propertyGroupID, let propertyIndex else { return nil }
        return PropertyReference(groupID: propertyGroupID, index: propertyIndex)
    }

    var cadovaTransform: Transform3D? {
        guard !transforms.isEmpty else { return nil }
        return transforms.map(\.cadovaTransform)
            .reduce(Transform3D.identity) { $0.concatenated(with: $1) }
    }
}

internal extension MeshData {
    /// Converts a 3MF mesh, resolving each triangle's property into a face material.
    ///
    /// A mesh names few distinct properties however many triangles it has, so each is resolved
    /// once and the answer reused for the rest.
    init(
        _ mesh: ThreeMF.Mesh,
        objectProperty: PropertyReference?,
        resolve: (PropertyReference) -> Material?
    ) {
        let vertices = mesh.vertices.map { Vector3D($0.x, $0.y, $0.z) }
        let faces = mesh.triangles.map { [$0.v1, $0.v2, $0.v3] }

        // A file that names no properties at all is the common case, and meshes run large, so it
        // skips the per-triangle pass rather than building a table of nothing.
        guard objectProperty != nil || mesh.triangles.contains(where: { $0.propertyIndex != nil }) else {
            self.init(vertices: vertices, faces: faces)
            return
        }

        var materialsByProperty: [PropertyReference: Material?] = [:]
        let materials = mesh.triangles.map { triangle -> Material? in
            guard let property = triangle.property(inheriting: objectProperty) else { return nil }
            if let known = materialsByProperty[property] {
                return known
            }
            let material = resolve(property)
            materialsByProperty[property] = .some(material)
            return material
        }
        self.init(vertices: vertices, faces: faces, faceMaterials: FaceMaterials(perFace: materials))
    }
}

internal extension ThreeMF.Mesh.Triangle {
    /// The property this triangle uses: its own, or the object's when it names none. Per-vertex
    /// properties give the whole triangle the first vertex's, since a face has a single material here.
    func property(inheriting objectProperty: PropertyReference?) -> PropertyReference? {
        guard let propertyIndex else { return objectProperty }
        guard let groupID = propertyGroup ?? objectProperty?.groupID else { return nil }
        return PropertyReference(groupID: groupID, index: propertyIndex.indices[0])
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
