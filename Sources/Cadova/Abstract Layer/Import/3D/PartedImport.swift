import Foundation
internal import ThreeMF

/// Imports a 3MF model, handing each item's geometry to a closure that decides what becomes of it.
internal struct PartedImport: Geometry3D {
    enum Source: Sendable {
        case url (URL)
        case data (Data)
    }

    let source: Source
    let parts: @Sendable (any Geometry3D, Import<D3>.ModelPart) throws -> any Geometry3D

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D3> {
        let format: ModelFileFormat?
        switch source {
        case .url (let url): format = try ModelFileFormat.detect(at: url)
        case .data (let data): format = ModelFileFormat.detect(from: data)
        }

        guard let format else {
            throw Import<D3>.ModelError.unrecognizedFormat
        }
        switch format {
        case .threeMF: break
        case .stlBinary, .stlASCII: throw Import<D3>.ModelError.partsNotSupported
        }

        switch source {
        case .url (let url):
            let loadedModel = try await context.threeMFModelCache.loadedModel(url: url)
            return try await build(loadedModel: loadedModel, in: environment, context: context)
        case .data (let data):
            let loadedModel = try await context.threeMFModelCache.loadedModel(data: data)
            return try await build(loadedModel: loadedModel, in: environment, context: context)
        }
    }

    private func build<T: Sendable>(
        loadedModel: ModelLoader<T>.LoadedModel,
        in environment: EnvironmentValues,
        context: EvaluationContext
    ) async throws -> BuildResult<D3> {
        let mapped = try loadedModel.items.enumerated().map { index, item in
            try parts(
                LoadedItemGeometry(model: loadedModel, item: item),
                .init(item: item, index: index)
            )
        }

        // The leading empty node guarantees a main output even when every part is routed into a
        // Part or left out, and covers a file without any build items.
        let geometries: [any Geometry3D] = [StaticNodeGeometry<D3>(.boolean([], type: .union))] + mapped

        return try await BuildResult<D3>(
            booleanOperation: .union,
            geometries: geometries,
            environment: environment,
            context: context
        )
    }
}

/// One item of a loaded 3MF model, converted into geometry nodes only once it's built.
///
/// `PartedImport` hands one of these to its closure for every item in the file. Copying an item's
/// meshes into `MeshData` isn't free, so items the closure leaves out never reach this point.
private struct LoadedItemGeometry<T: Sendable>: Geometry3D {
    let model: ModelLoader<T>.LoadedModel
    let item: ModelLoader<T>.LoadedModel.LoadedItem

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D3> {
        .init(item.buildNode(model: model))
    }
}
