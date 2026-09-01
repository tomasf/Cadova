import Foundation
internal import ThreeMF

/// Caches parsed 3MF `LoadedModel`s for the lifetime of one `EvaluationContext`, so repeated
/// `Import` calls against the same file or data — including multiple `Import` call sites in one
/// project, and repeated `_build` invocations from reference re-evaluation — unzip and parse the
/// package only once. Mirrors `GeometryCache`'s actor + Task-dictionary shape.
internal actor ThreeMFModelCache {
    private var urlTasks: [URL: Task<ModelLoader<URL>.LoadedModel, any Error>] = [:]
    private var dataTasks: [Data: Task<ModelLoader<Data>.LoadedModel, any Error>] = [:]

    func loadedModel(url: URL) async throws -> ModelLoader<URL>.LoadedModel {
        if let task = urlTasks[url] {
            return try await task.value
        }
        let task = Task { try await ModelLoader(url: url).load() }
        urlTasks[url] = task
        return try await task.value
    }

    func loadedModel(data: Data) async throws -> ModelLoader<Data>.LoadedModel {
        if let task = dataTasks[data] {
            return try await task.value
        }
        let task = Task { try await ModelLoader(data: data).load() }
        dataTasks[data] = task
        return try await task.value
    }
}
