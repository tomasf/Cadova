// Runs builds off the main thread, so the page stays responsive while the model builds

import { fetchModel, fetchResources, listParameters, runModel } from "./runner.js";

let compiledModule, resources;

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
            compiledModule = await WebAssembly.compile(bytes);
            resources = loadedResources;
            self.postMessage({ type: "prepared", id: data.id, compiledModule, resources });
            self.postMessage({ type: "ready", id: data.id, ...(await listParameters(compiledModule, resources)) });
        } else if (data.type === "initialize") {
            compiledModule = data.compiledModule;
            resources = data.resources;
            self.postMessage({ type: "ready", id: data.id,
                ...(data.catalog ?? await listParameters(compiledModule, resources)) });
        } else if (data.type === "build") {
            self.postMessage({ type: "built", id: data.id, ...(await runModel(compiledModule, resources, data.model, data.parameters)) });
        }
    } catch (error) {
        self.postMessage({ type: "error", id: data.id, message: String(error?.message ?? error) });
    }
};
