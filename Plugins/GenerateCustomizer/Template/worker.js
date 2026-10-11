// Runs builds off the main thread, so the page stays responsive while the model builds

import { fetchModel, fetchResources, listParameters, runModel } from "./runner.js";

let compiledModule, resources;

self.onmessage = async ({ data }) => {
    try {
        if (data.type === "load") {
            const resourcesLoaded = fetchResources(data.url);
            const bytes = await fetchModel(data.url, (received, total) => {
                self.postMessage({ type: "progress", received, total });
            });
            self.postMessage({ type: "compiling" });
            compiledModule = await WebAssembly.compile(bytes);
            resources = await resourcesLoaded;
            self.postMessage({ type: "ready", ...(await listParameters(compiledModule, resources)) });
        } else if (data.type === "build") {
            self.postMessage({ type: "built", id: data.id, ...(await runModel(compiledModule, resources, data.model, data.parameters)) });
        }
    } catch (error) {
        self.postMessage({ type: "error", id: data.id, message: String(error?.message ?? error) });
    }
};
