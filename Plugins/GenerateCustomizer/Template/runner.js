// Runs the model, compiled to WebAssembly, as a WASI program, in an in-memory directory that holds
// each request and receives what the model writes. Cadova finds the request through
// CADOVA_CUSTOMIZER_REQUEST. The model's resources are in the root directory. Model execution stays
// in the worker so it can be cancelled.

import {
    WASI, WASIProcExit, File, Directory, OpenFile, ConsoleStdout, PreopenDirectory,
} from "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.2/dist/index.js";

export async function fetchModel(url, onProgress = () => {}) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Couldn't load ${url} (${response.status})`);
    const total = Number(response.headers.get("Content-Length")) || 0;
    const reader = response.body.getReader();
    const chunks = [];
    let received = 0;
    for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
        received += value.length;
        onProgress(received, total);
    }
    const bytes = new Uint8Array(received);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return bytes;
}

// Fetches the model's resources: the files SwiftPM copies for `.copy` and `.process` resources,
// listed in resources.json. WASI file reads are synchronous, so they're all fetched up front.
export async function fetchResources(baseURL) {
    const response = await fetch(new URL("resources.json", baseURL));
    if (!response.ok) throw new Error(`Couldn't load the list of resources (${response.status})`);
    const paths = await response.json();
    return Promise.all(paths.map(async (path) => {
        const url = new URL(`resources/${path.split("/").map(encodeURIComponent).join("/")}`, baseURL);
        const file = await fetch(url);
        if (!file.ok) throw new Error(`Couldn't load the resource ${path} (${file.status})`);
        return [path, new Uint8Array(await file.arrayBuffer())];
    }));
}

// The resource bundles as a directory tree, for the root directory, where Bundle.module looks for
// them on WASI. The files share the fetched data, read-only, so each run gets its own tree cheaply.
function resourceDirectory(resources) {
    const root = new Map();
    for (const [path, bytes] of resources) {
        const parts = path.split("/");
        let directory = root;
        for (const part of parts.slice(0, -1)) {
            if (!directory.has(part)) directory.set(part, new Directory(new Map()));
            directory = directory.get(part).contents;
        }
        directory.set(parts.at(-1), new File(bytes, { readonly: true }));
    }
    return root;
}

// One instance of the model, kept between requests so that each build reuses the geometry Cadova
// has cached from the ones before it. The first request starts the program. Rather than exiting
// once it's handled, Cadova then suspends the program with a status of its own, leaving the
// instance in place, and later requests call its cadova_customizer_request export instead. If the
// program exits or crashes, the instance is discarded, and the next request starts a new one.
export class ModelSession {
    static suspendedStatus = 51920;

    constructor(compiledModule, resources) {
        this.compiledModule = compiledModule;
        this.resources = resources;
        this.instance = null; // a suspended instance, ready for its next request
        this.files = new Map(); // the instance's /io directory
        this.output = [];
    }

    // Asks for every model's parameters, title and description as JSON, which builds nothing
    async listParameters() {
        const result = await this.run({ listParameters: "/io/parameters.json" }, "parameters.json");
        const catalog = result.data ? JSON.parse(new TextDecoder().decode(result.data)) : null;
        return { catalog, log: result.log, stackOverflow: result.stackOverflow };
    }

    // Builds one model with the given parameter values, by label. Values are passed as strings, which
    // each parameter parses as its own type.
    async build(model, values) {
        const strings = Object.fromEntries(Object.entries(values).map(([label, value]) => [label, String(value)]));
        return this.run({ model, values: strings, output: "/io" }, ".3mf");
    }

    async run(request, outputSuffix) {
        const start = performance.now();
        // Everything the model writes is kept, and split into lines at the end, so that a last line
        // without a line break, such as a message written just before a crash, isn't lost
        this.output = [];
        const starting = this.instance ? null : await this.instantiate();
        this.files.clear();
        this.files.set("request.json", new File(new TextEncoder().encode(JSON.stringify(request))));

        let exitCode, stackOverflow = false, crash = null;
        try {
            if (starting) {
                exitCode = starting.wasi.start(starting.instance);
                if (exitCode === ModelSession.suspendedStatus) {
                    this.instance = starting.instance;
                    exitCode = 0;
                }
            } else {
                exitCode = this.instance.exports.cadova_customizer_request();
            }
        } catch (error) {
            this.instance = null;
            if (error instanceof WASIProcExit) {
                exitCode = error.code;
            } else {
                // A trap: Swift runtime failures and C++ exceptions end up here, as does running out of
                // native stack (RangeError in Chrome and Safari, InternalError in Firefox)
                stackOverflow = error instanceof RangeError || error?.name === "InternalError";
                crash = `Crashed: ${error?.message ?? error}`;
                exitCode = -1;
            }
        }
        const text = new TextDecoder().decode(new Uint8Array(this.output.flatMap((bytes) => [...bytes])));
        const log = text.split("\n").filter((line, index, lines) => line !== "" || index < lines.length - 1);
        if (crash) log.push(crash);
        const milliseconds = performance.now() - start;

        const [fileName, file] = [...this.files].find(([name]) => name.endsWith(outputSuffix)) ?? [];
        const data = exitCode === 0 && file ? file.data : null;
        return { fileName, data, log, exitCode, stackOverflow, milliseconds };
    }

    // A new instance, with a new /io directory, that hasn't started yet. CADOVA_CUSTOMIZER_SESSION
    // asks Cadova to suspend rather than exit; a model built with a Cadova that doesn't know it just
    // exits, and then every request starts a new instance.
    async instantiate() {
        this.files = new Map();
        const write = (bytes) => this.output.push(bytes.slice());
        const environment = [
            "CADOVA_LOG_LEVEL=info", "CADOVA_CUSTOMIZER_REQUEST=/io/request.json", "CADOVA_CUSTOMIZER_SESSION=1",
        ];
        const wasi = new WASI(["model"], environment, [
            new OpenFile(new File([])),
            new ConsoleStdout(write),
            new ConsoleStdout(write),
            new PreopenDirectory("/io", this.files),
            new PreopenDirectory("/", resourceDirectory(this.resources)),
        ], { debug: false });
        const instance = await WebAssembly.instantiate(this.compiledModule, { wasi_snapshot_preview1: wasi.wasiImport });
        return { wasi, instance };
    }
}
