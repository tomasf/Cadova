// Runs builds off the main thread, so the page stays responsive while the model builds

import { fetchModel, fetchResources, ModelSession } from "./runner.js";

let session;

self.onmessage = async ({ data }) => {
    try {
        if (data.type === "load") {
            const [bytes, loadedResources] = await Promise.all([
                fetchModel(data.url, (received, total) => {
                    self.postMessage({ type: "progress", id: data.id, received, total });
                }),
                fetchResources(data.url),
            ]);
            self.postMessage({ type: "compiling", id: data.id });
            const compiledModule = await WebAssembly.compile(bytes);
            self.postMessage({ type: "prepared", id: data.id, compiledModule, resources: loadedResources });
            session = new ModelSession(compiledModule, loadedResources);
            self.postMessage({ type: "ready", id: data.id, ...(await session.listParameters()) });
        } else if (data.type === "initialize") {
            session = new ModelSession(data.compiledModule, data.resources);
            self.postMessage({ type: "ready", id: data.id, ...(data.catalog ?? await session.listParameters()) });
        } else if (data.type === "build" || data.type === "export") {
            const result = await session[data.type](data.model, data.parameters);
            self.postMessage({ type: "built", id: data.id, ...result }, result.data ? [result.data.buffer] : []);
            session.pruneCache();
            // For the build details: how much memory the model uses, once its cache is pruned
            const cacheBytes = session.cacheByteCount();
            if (cacheBytes !== null) {
                self.postMessage({ type: "memory", memoryBytes: session.instance.exports.memory.buffer.byteLength, cacheBytes });
            }
        }
    } catch (error) {
        self.postMessage({ type: "error", id: data.id, message: String(error?.message ?? error) });
    }
};
