// Runs the model, compiled to WebAssembly, as a WASI program: a fresh run of the model's
// executable for each request, in an in-memory directory that holds the request and receives what
// the model writes. Cadova finds the request through CADOVA_CUSTOMIZER_REQUEST. The model's
// resources are in the root directory. Model execution stays in the worker so it can be cancelled.

import {
    WASI, File, Directory, OpenFile, ConsoleStdout, PreopenDirectory,
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

// Asks for every model's parameters, title and description as JSON, which builds nothing
export async function listParameters(compiledModule, resources) {
    const result = await run(compiledModule, resources, { listParameters: "/io/parameters.json" }, "parameters.json");
    const catalog = result.data ? JSON.parse(new TextDecoder().decode(result.data)) : null;
    return { catalog, log: result.log, stackOverflow: result.stackOverflow };
}

// Builds one model with the given parameter values, by label. Values are passed as strings, which
// each parameter parses as its own type.
export async function runModel(compiledModule, resources, model, values) {
    const strings = Object.fromEntries(Object.entries(values).map(([label, value]) => [label, String(value)]));
    return run(compiledModule, resources, { model, values: strings, output: "/io" }, ".3mf");
}

async function run(compiledModule, resources, request, outputSuffix) {
    const files = new Map([["request.json", new File(new TextEncoder().encode(JSON.stringify(request)))]]);
    // Everything the model writes is kept, and split into lines at the end, so that a last line
    // without a line break, such as a message written just before a crash, isn't lost
    const output = [];
    const environment = ["CADOVA_LOG_LEVEL=info", "CADOVA_CUSTOMIZER_REQUEST=/io/request.json"];
    const wasi = new WASI(["model"], environment, [
        new OpenFile(new File([])),
        new ConsoleStdout((bytes) => output.push(bytes.slice())),
        new ConsoleStdout((bytes) => output.push(bytes.slice())),
        new PreopenDirectory("/io", files),
        new PreopenDirectory("/", resourceDirectory(resources)),
    ], { debug: false });

    const start = performance.now();
    const instance = await WebAssembly.instantiate(compiledModule, { wasi_snapshot_preview1: wasi.wasiImport });
    let exitCode, stackOverflow = false, crash = null;
    try {
        exitCode = wasi.start(instance);
    } catch (error) {
        // A trap: Swift runtime failures and C++ exceptions end up here, as does running out of
        // native stack (RangeError in Chrome and Safari, InternalError in Firefox)
        stackOverflow = error instanceof RangeError || error?.name === "InternalError";
        crash = `Crashed: ${error?.message ?? error}`;
        exitCode = -1;
    }
    const text = new TextDecoder().decode(new Uint8Array(output.flatMap((bytes) => [...bytes])));
    const log = text.split("\n").filter((line, index, lines) => line !== "" || index < lines.length - 1);
    if (crash) log.push(crash);
    const milliseconds = performance.now() - start;

    const [fileName, file] = [...files].find(([name]) => name.endsWith(outputSuffix)) ?? [];
    const data = exitCode === 0 && file ? file.data : null;
    return { fileName, data, log, exitCode, stackOverflow, milliseconds };
}
