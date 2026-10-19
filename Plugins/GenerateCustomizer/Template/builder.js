// Owns the worker and one request at a time. Terminating a worker also stops synchronous WASM
// execution, so cancellation and timeouts work even when the model can't process another message.
// Keep the compiled module and resources so restarting doesn't download or compile them again.
export class CancelledError extends Error {}

export class ModelBuilder {
    constructor(url, onProgress) {
        this.url = url;
        this.onProgress = onProgress;
        this.worker = null;
        this.pending = null;
        this.prepared = null;
        this.catalog = null;
        this.ready = false;
        this.nextID = 0;
    }

    // The address of one of the customizer's files. The plugin marks a customizer's addresses with
    // its version, so that a browser never mixes files from two versions, and this one has it too.
    address(path) {
        const url = new URL(path, this.url);
        url.search = new URL(this.url).search;
        return url;
    }

    async load() {
        if (this.ready) return this.catalog;
        const result = await this.request(this.prepared
            ? { type: "initialize", ...this.prepared, catalog: this.catalog }
            : { type: "load", url: this.address("model.wasm").href });
        if (!result.catalog) {
            this.cancel();
            const error = new Error(result.stackOverflow
                ? "The model exceeds this browser's worker stack limit. Try a simpler model or reduce its resolution."
                : "The model couldn't list its parameters. See the build details.");
            error.log = result.log;
            throw error;
        }
        this.catalog = { catalog: result.catalog, log: result.log, stackOverflow: result.stackOverflow };
        this.ready = true;
        return this.catalog;
    }

    async build(model, parameters) {
        await this.load();
        // A failed build keeps the worker: its model session replaces an instance that crashed or
        // exited by itself, and one that only reported a failure keeps its cache for the next build.
        return this.request({ type: "build", model, parameters });
    }

    // Builds the model file to download, for parameters the model has just built its preview with
    async export(model, parameters) {
        await this.load();
        return this.request({ type: "export", model, parameters });
    }

    cancel() {
        this.fail(new CancelledError("Cancelled."));
    }

    fail(error) {
        const pending = this.pending;
        this.pending = null;
        clearTimeout(pending?.timer);
        this.worker?.terminate();
        this.worker = null;
        this.ready = false;
        pending?.reject(error);
    }

    request(message) {
        return new Promise((resolve, reject) => {
            if (this.pending) {
                reject(new Error("A model request is already running."));
                return;
            }
            const id = ++this.nextID;
            // Both loading and building have a two-minute limit. A slow or stuck model must never
            // leave the page busy indefinitely; the visitor can cancel sooner or retry afterward.
            const timer = setTimeout(() => {
                if (this.pending?.id !== id) return;
                this.fail(new Error({
                    build: "Build stopped after 2 minutes. Try simpler settings or retry.",
                    export: "Preparing the download stopped after 2 minutes. Please retry.",
                }[message.type] ?? "Loading the model took longer than 2 minutes. Please retry."));
            }, 120_000);
            this.pending = { id, timer, resolve, reject };
            try {
                if (!this.worker) this.startWorker();
                this.worker.postMessage({ ...message, id });
            } catch (error) {
                this.fail(error);
            }
        });
    }

    startWorker() {
        const worker = new Worker(this.address("worker.js"), { type: "module" });
        this.worker = worker;
        worker.onerror = (event) => {
            if (this.worker !== worker) return;
            event.preventDefault();
            this.fail(new Error(`The model worker stopped unexpectedly. ${event.message || "Please retry."}`));
        };
        worker.onmessageerror = () => {
            if (this.worker === worker) this.fail(new Error("Couldn't read the model worker's response. Please retry."));
        };
        worker.onmessage = ({ data }) => {
            // Reported after a request has finished, so it doesn't belong to one
            if (data.type === "memory") {
                if (this.worker === worker) this.onProgress(data);
                return;
            }
            // Messages already queued when a worker was stopped must not finish a newer request.
            if (this.worker !== worker || data.id !== this.pending?.id) return;
            switch (data.type) {
                case "prepared":
                    this.prepared = { compiledModule: data.compiledModule, resources: data.resources };
                    break;
                case "progress":
                case "compiling":
                    this.onProgress(data);
                    break;
                case "error":
                    this.fail(new Error(data.message));
                    break;
                case "ready":
                case "built": {
                    const pending = this.pending;
                    this.pending = null;
                    clearTimeout(pending.timer);
                    pending.resolve(data);
                    break;
                }
            }
        };
    }
}
