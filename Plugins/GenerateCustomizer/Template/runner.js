// Runs the model, compiled to WebAssembly, as a WASI program: a fresh run of the model's
// executable for each request, in an in-memory directory that holds the request and receives what
// the model writes. Cadova finds the request through CADOVA_CUSTOMIZER_REQUEST. Used both by the
// worker and, as a fallback, by the page itself.

import {
    WASI, File, OpenFile, ConsoleStdout, PreopenDirectory,
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

// Asks for every model's parameters, title and description as JSON, which builds nothing
export async function listParameters(compiledModule) {
    const result = await run(compiledModule, { listParameters: "/io/parameters.json" }, "parameters.json");
    const catalog = result.data ? JSON.parse(new TextDecoder().decode(result.data)) : null;
    return { catalog, log: result.log, stackOverflow: result.stackOverflow };
}

// Builds one model with the given parameter values, by label. Values are passed as strings, which
// each parameter parses as its own type.
export async function runModel(compiledModule, model, values) {
    const strings = Object.fromEntries(Object.entries(values).map(([label, value]) => [label, String(value)]));
    return run(compiledModule, { model, values: strings, output: "/io" }, ".3mf");
}

async function run(compiledModule, request, outputSuffix) {
    const files = new Map([["request.json", new File(new TextEncoder().encode(JSON.stringify(request)))]]);
    const log = [];
    const environment = ["CADOVA_LOG_LEVEL=info", "CADOVA_CUSTOMIZER_REQUEST=/io/request.json"];
    const wasi = new WASI(["model"], environment, [
        new OpenFile(new File([])),
        ConsoleStdout.lineBuffered((line) => log.push(line)),
        ConsoleStdout.lineBuffered((line) => log.push(line)),
        new PreopenDirectory("/io", files),
    ], { debug: false });

    const start = performance.now();
    const instance = await WebAssembly.instantiate(compiledModule, { wasi_snapshot_preview1: wasi.wasiImport });
    let exitCode, stackOverflow = false;
    try {
        exitCode = wasi.start(instance);
    } catch (error) {
        // A trap: Swift runtime failures and C++ exceptions end up here, as does running out of
        // native stack (RangeError in Chrome and Safari, InternalError in Firefox)
        stackOverflow = error instanceof RangeError || error?.name === "InternalError";
        log.push(`Crashed: ${error?.message ?? error}`);
        exitCode = -1;
    }
    const milliseconds = performance.now() - start;

    const [fileName, file] = [...files].find(([name]) => name.endsWith(outputSuffix)) ?? [];
    const data = exitCode === 0 && file ? file.data : null;
    return { fileName, data, log, exitCode, stackOverflow, milliseconds };
}
