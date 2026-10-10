// Runs the model, compiled to WebAssembly, as a WASI program: a fresh run of the model's
// executable for each build, with the parameters as command line arguments and an in-memory
// directory for it to write the model file into. Used both by the worker and, as a fallback, by
// the page itself.

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

// Runs the model with --list-parameters, which builds nothing and writes every model's parameters,
// title and description to a file as JSON
export async function listParameters(compiledModule) {
    const result = await run(compiledModule, ["model", "--list-parameters=/out/parameters.json"], "parameters.json");
    const catalog = result.data ? JSON.parse(new TextDecoder().decode(result.data)) : null;
    return { catalog, log: result.log, stackOverflow: result.stackOverflow };
}

export async function runModel(compiledModule, model, parameters) {
    const args = ["model", "--model", model, "--output", "/out"];
    for (const [name, value] of Object.entries(parameters)) args.push("--param", `${name}=${value}`);
    return run(compiledModule, args, ".3mf");
}

async function run(compiledModule, args, outputSuffix) {
    const files = new Map();
    const log = [];
    const wasi = new WASI(args, ["CADOVA_LOG_LEVEL=info"], [
        new OpenFile(new File([])),
        ConsoleStdout.lineBuffered((line) => log.push(line)),
        ConsoleStdout.lineBuffered((line) => log.push(line)),
        new PreopenDirectory("/out", files),
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
