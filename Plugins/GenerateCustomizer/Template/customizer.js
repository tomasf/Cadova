import * as THREE from "three";
import { ViewportControls } from "./navigation.js";
import { toCreasedNormals } from "three/addons/utils/BufferGeometryUtils.js";
import { ModelBuilder, CancelledError } from "./builder.js";
import { read3MF } from "./threemf.js";
import { readPreview } from "./preview.js";
import { ViewportGrid } from "./grid.js";
import { OriginAxes, AxisIndicator } from "./axes.js";
import { frameIsometric } from "./camera.js";
import { ViewportRenderer } from "./rendering.js";
import { setupLighting } from "./lighting.js";

const $ = (id) => document.getElementById(id);

// The models and their parameters come from the model itself, listed once it has loaded. A
// parameter is identified by its label within its model, and each model keeps its own values. Only
// changed values are kept, by model; everything else has its default.
let catalog, models, model;
const changed = new Map();

function changedValues(m) {
    if (!changed.has(m.name)) changed.set(m.name, {});
    return changed.get(m.name);
}

// MARK: Form

const form = $("parameters");
const controls = new Map();
const tabs = new Map();

// Sets the page up for the model chosen by the page's cadova-model meta tag, or else every model that
// has parameters, with a tab for each
function setUp(listing) {
    catalog = listing;
    const chosen = document.querySelector('meta[name="cadova-model"]')?.content;
    models = catalog.models.filter((m) => chosen ? m.name === chosen : m.parameters.length > 0);
    if (!models.length) throw new Error(chosen ? `The model "${chosen}" wasn't found.` : "No model has parameters to customize.");

    const hash = new URLSearchParams(location.hash.slice(1));
    model = models.find((m) => m.name === hash.get("model")) ?? models[0];
    Object.assign(changedValues(model), valuesFromHash(hash, model));

    const single = models.length === 1;
    const title = single ? models[0].title ?? humanize(models[0].name.split("/").pop()) : catalog.title ?? "Customizer";
    document.title = `${title} customizer`;
    $("title").textContent = title;
    const description = single ? models[0].description : catalog.description;
    if (description) $("subtitle").textContent = description;

    if (!single) {
        for (const m of models) {
            const tab = Object.assign(document.createElement("button"), { type: "button", textContent: tabTitle(m) });
            tab.setAttribute("role", "tab");
            tab.addEventListener("click", () => select(m));
            $("models").append(tab);
            tabs.set(m, tab);
        }
        $("models").hidden = false;
    }
    showForm();
}

// A project's metadata applies to every model that doesn't override it, so a model whose title is the
// project's is named after itself instead
function tabTitle(m) {
    return m.title && m.title !== catalog.title ? m.title : humanize(m.name.split("/").pop());
}

function showForm() {
    form.replaceChildren();
    controls.clear();
    for (const [m, tab] of tabs) tab.setAttribute("aria-selected", m === model);
    if (tabs.size && model.description && model.description !== catalog.description) {
        form.append(Object.assign(document.createElement("p"), { className: "model-description", textContent: model.description }));
    }
    model.parameters.forEach((parameter, index) => form.append(field(parameter, index)));
}

function select(next) {
    if (next === model) return;
    model = next;
    showForm();
    writeHash();
    const build = builds.get(model.name);
    if (build?.data && build.key === buildKey(model)) {
        try {
            display(build);
        } catch (error) {
            builds.delete(model.name);
            failed(error);
        }
    } else {
        downloadable = null;
        $("download").disabled = true;
        requestBuild();
    }
}

// The value a parameter of a model gets: a changed value made to fit it (clamped to its range, or its
// default if it's not a value this parameter can take, as can happen with a hand-edited address), or
// else its default
function valueFor(parameter, m = model) {
    const value = changed.get(m.name)?.[parameter.label];
    if (value === undefined) return parameter.default;
    switch (parameter.type) {
        case "boolean":
            return typeof value === "boolean" ? value : parameter.default;
        case "choice":
            return parameter.options.includes(value) ? value : parameter.default;
        case "integer":
        case "number":
        case "angle": {
            if (typeof value !== "number" || Number.isNaN(value)) return parameter.default;
            let result = parameter.type === "integer" ? Math.round(value) : value;
            if (parameter.minimum !== undefined) result = Math.max(result, parameter.minimum);
            if (parameter.maximum !== undefined) result = Math.min(result, parameter.maximum);
            return result;
        }
        default:
            return String(value);
    }
}

function valuesFor(m) {
    return Object.fromEntries(m.parameters.map((parameter) => [parameter.label, valueFor(parameter, m)]));
}

function buildKey(m) {
    return JSON.stringify(valuesFor(m));
}

function field(parameter, index) {
    const element = document.createElement("div");
    element.className = "field";
    const id = `parameter-${index}`;
    const head = document.createElement("div");
    head.className = "field-head";
    const label = document.createElement("label");
    label.htmlFor = id;
    label.textContent = parameter.label;
    head.append(label);
    element.append(head);
    if (parameter.description) {
        const help = document.createElement("div");
        help.className = "help";
        help.textContent = parameter.description;
        element.append(help);
    }
    const control = document.createElement("div");
    control.className = "control";
    element.append(control);

    let setValue;
    switch (parameter.type) {
        case "boolean": {
            // A label around the checkbox, so a click anywhere on the switch toggles it
            const toggle = document.createElement("label");
            toggle.className = "toggle";
            const input = Object.assign(document.createElement("input"), { type: "checkbox", id });
            input.addEventListener("change", () => update(parameter.label, input.checked));
            toggle.append(input, document.createElement("span"));
            head.append(toggle);
            element.removeChild(control);
            setValue = (value) => { input.checked = value; };
            break;
        }
        case "choice": {
            if (parameter.options.length <= 4) {
                const group = document.createElement("div");
                group.className = "segmented";
                group.setAttribute("role", "group");
                group.setAttribute("aria-labelledby", `${id}-label`);
                label.id = `${id}-label`;
                label.removeAttribute("for");
                const buttons = parameter.options.map((option) => {
                    const button = Object.assign(document.createElement("button"), {
                        type: "button", textContent: humanize(option),
                    });
                    button.addEventListener("click", () => { setValue(option); update(parameter.label, option); });
                    group.append(button);
                    return [option, button];
                });
                control.append(group);
                setValue = (value) => {
                    for (const [option, button] of buttons) button.setAttribute("aria-pressed", option === value);
                };
            } else {
                const select = Object.assign(document.createElement("select"), { id });
                for (const option of parameter.options) select.append(new Option(humanize(option), option));
                select.addEventListener("change", () => update(parameter.label, select.value));
                control.append(select);
                setValue = (value) => { select.value = value; };
            }
            break;
        }
        case "integer":
        case "number":
        case "angle": {
            const step = parameter.step ?? (parameter.type === "integer" ? 1 : "any");
            const number = Object.assign(document.createElement("input"), { type: "number", id, step });
            if (parameter.minimum !== undefined) number.min = parameter.minimum;
            if (parameter.maximum !== undefined) number.max = parameter.maximum;
            let range;
            if (parameter.minimum !== undefined && parameter.maximum !== undefined) {
                range = Object.assign(document.createElement("input"), {
                    type: "range", min: parameter.minimum, max: parameter.maximum, step,
                });
                range.setAttribute("aria-label", parameter.label);
                range.addEventListener("input", () => {
                    number.value = range.value;
                    update(parameter.label, Number(range.value));
                });
                control.append(range);
            }
            number.addEventListener("change", () => {
                if (number.value === "" || !number.checkValidity()) {
                    number.value = valueFor(parameter);
                    return;
                }
                if (range) range.value = number.value;
                update(parameter.label, Number(number.value));
            });
            control.append(number);
            if (parameter.type === "angle") {
                control.append(Object.assign(document.createElement("span"), { className: "unit", textContent: "°" }));
            }
            setValue = (value) => { number.value = value; if (range) range.value = value; };
            break;
        }
        default: {
            const input = Object.assign(document.createElement("input"), { type: "text", id });
            input.addEventListener("change", () => update(parameter.label, input.value));
            control.append(input);
            setValue = (value) => { input.value = value; };
        }
    }
    setValue(valueFor(parameter));
    controls.set(parameter.label, setValue);
    return element;
}

function update(label, value) {
    changedValues(model)[label] = value;
    requestBuild();
    writeHash();
}

$("reset").addEventListener("click", () => {
    changed.delete(model.name);
    for (const parameter of model.parameters) controls.get(parameter.label)(parameter.default);
    writeHash();
    requestBuild();
});

// The model on screen and its changed values are kept in the address, so a configured model can be
// shared
function valuesFromHash(hash, m) {
    const result = {};
    for (const [label, raw] of hash) {
        if (label === "model" && models.length > 1) continue;
        const parameter = m.parameters.find((p) => p.label === label);
        if (!parameter) continue;
        result[label] = parameter.type === "boolean" ? raw === "true"
            : ["integer", "number", "angle"].includes(parameter.type) ? Number(raw) : raw;
    }
    return result;
}

// Safari allows only 100 address changes per 10 seconds and throws past that, and a dragged slider
// changes values far faster. So the address changes at most every 250 ms, ending with the latest
// values, and a failure to change it is never allowed to stop anything else.
const hashInterval = 250;
let lastHashWrite = 0, hashTimer = null;

function writeHash() {
    if (hashTimer) return;
    const wait = Math.max(0, lastHashWrite + hashInterval - performance.now());
    hashTimer = setTimeout(() => {
        hashTimer = null;
        lastHashWrite = performance.now();
        const entries = Object.entries(changed.get(model.name) ?? {});
        if (model !== models[0]) entries.unshift(["model", model.name]);
        try {
            history.replaceState(null, "", entries.length ? `#${new URLSearchParams(entries)}` : location.pathname);
        } catch (error) {
            console.warn("Couldn't update the address:", error);
        }
    }, wait);
}

function humanize(name) {
    const words = name.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[-_]+/g, " ").trim().toLowerCase();
    return words.charAt(0).toUpperCase() + words.slice(1);
}

// MARK: Building

let isReady = false, loading = false, loadAttempt = 0;
let building = null; // the model and values of the build in progress
const builds = new Map(); // the last build of each model, with the values it was built with
// The model and values of the build on screen, while they match the controls, to download a file of
let downloadable = null, shownModel = null;
let exporting = false; // whether the file to download is being made
let buildTimer;

const builder = new ModelBuilder(import.meta.url, (data) => {
    if (data.type === "progress") {
        const megabytes = (bytes) => (bytes / 1e6).toFixed(0);
        $("overlay-text").textContent = data.total
            ? `Loading model… ${megabytes(data.received)} of ${megabytes(data.total)} MB`
            : `Loading model… ${megabytes(data.received)} MB`;
        if (data.total) $("progress-bar").style.width = `${(100 * data.received) / data.total}%`;
    } else if (data.type === "memory") {
        const megabytes = (bytes) => Math.round(bytes / 1e6).toLocaleString();
        $("memory").textContent = `Memory: ${megabytes(data.memoryBytes)} MB, of which cache about ${megabytes(data.cacheBytes)} MB`;
        $("memory").hidden = false;
    } else if (data.type === "compiling") {
        $("overlay-text").textContent = "Preparing model…";
        $("progress-bar").style.width = "100%";
    }
});

let cancelTimer;

function busy(active, text = "Building…") {
    clearTimeout(cancelTimer);
    $("build-progress").hidden = !active;
    $("building").hidden = !active;
    $("building").textContent = text;
    $("cancel").hidden = true;
    $("retry").hidden = true;
    $("reset").disabled = !isReady;
    form.setAttribute("aria-busy", active);
    if (active) {
        cancelTimer = setTimeout(() => { $("cancel").hidden = false; }, 3000);
        downloadable = null;
        $("download").disabled = true;
        setStatus("");
        $("build-time").textContent = text;
        if (!shownModel) {
            $("overlay").hidden = false;
            $("overlay-text").textContent = text;
            $("progress-bar").parentElement.hidden = text !== "Loading model…";
            $("progress-bar").style.width = "0%";
        }
    }
}

function failed(error) {
    builder.cancel();
    clearTimeout(buildTimer);
    busy(false);
    downloadable = null;
    $("download").disabled = true;
    $("retry").textContent = isReady ? "Retry build" : "Retry loading";
    $("retry").hidden = false;
    $("build-time").textContent = error instanceof CancelledError ? "Cancelled" : "Failed";
    buildLog.show(error.log ?? [error.message]);
    setStatus(error.message, true);
    if (!shownModel) {
        $("overlay-text").textContent = error.message;
        $("progress-bar").parentElement.hidden = true;
    }
}

async function initialize() {
    const attempt = ++loadAttempt;
    loading = true;
    busy(true, "Loading model…");
    try {
        const result = await builder.load();
        if (attempt !== loadAttempt) return;
        setUp(result.catalog);
        isReady = true;
        loading = false;
        startBuild();
    } catch (error) {
        if (attempt !== loadAttempt) return;
        loading = false;
        failed(error);
    }
}

function requestBuild() {
    clearTimeout(buildTimer);
    // A download must match the current controls, including while a rebuild is debounced or queued.
    downloadable = null;
    $("download").disabled = true;
    buildTimer = setTimeout(startBuild, 120);
}

async function startBuild() {
    if (!isReady || loading || building || exporting) return;
    clearTimeout(buildTimer);
    const parameters = valuesFor(model);
    const attempt = { model, parameters, key: JSON.stringify(parameters) };
    building = attempt;
    busy(true);
    try {
        const result = await builder.build(attempt.model.name, parameters);
        if (building !== attempt) return;
        finishBuild(result, attempt);
    } catch (error) {
        if (building !== attempt) return;
        building = null;
        failed(error);
    }
}

function finishBuild(result, finished) {
    building = null;
    busy(false);
    const build = { ...result, key: finished.key, parameters: finished.parameters };
    builds.set(finished.model.name, build);
    // Keep the last preview while the latest parameters build. Never enable a download for stale
    // parameters, or report an obsolete build's error against the newly selected model.
    if (finished.model === model && finished.key === buildKey(model)) {
        if (!result.data) {
            const error = new Error(result.stackOverflow
                ? "The model exceeds this browser's worker stack limit. Try simpler settings or reduce its resolution."
                : result.exitCode === 0 ? "The model built to nothing. Try different settings."
                : "The model failed to build. See the build details.");
            error.log = result.log;
            failed(error);
            return;
        }
        try {
            display(build);
        } catch (error) {
            failed(error);
            return;
        }
    }
    if (builds.get(model.name)?.key !== buildKey(model)) startBuild();
}

$("cancel").addEventListener("click", () => {
    ++loadAttempt;
    loading = false;
    building = null;
    failed(new CancelledError(isReady ? "Build cancelled." : "Loading cancelled."));
});

$("retry").addEventListener("click", () => {
    if (isReady) startBuild();
    else initialize();
});

// Starts after the viewer has been initialized, so even an immediately answered request can display.
queueMicrotask(initialize);

function display({ fileName, data, log, exitCode, milliseconds, parameters }) {
    buildLog.show(log);
    if (data) {
        $("retry").hidden = true;
        downloadable = { model, parameters };
        $("download").disabled = false;
        setStatus(`Built in ${Math.round(milliseconds)} ms`);
        show(data, fileName, shownModel !== model);
        shownModel = model;
    } else {
        downloadable = null;
        $("download").disabled = true;
        setStatus(exitCode === 0 ? "The model built to nothing." : "The model failed to build. See the build details.", true);
    }
}

// What the model wrote while building, a message per line. Most messages are informational, so only
// warnings and errors are labeled, and timestamps are left out.
const buildLog = {
    show(lines) {
        $("log").replaceChildren(...lines.map((line) => {
            const text = line.replace(/^\d{4}-\d{2}-\d{2}T\S+ /, "");
            const [, level, message] = text.match(/^(?:\S+ )?\[(DEBUG|INFO|WARNING|ERROR)\] (.*)$/s) ?? [null, null, text];
            const element = document.createElement("div");
            if (level === "WARNING") {
                element.className = "warning";
                element.textContent = `Warning: ${message}`;
            } else if (level === "ERROR" || text.startsWith("Crashed:")) {
                element.className = "error";
                element.textContent = level ? `Error: ${message}` : message;
            } else {
                element.textContent = message;
            }
            return element;
        }));
    },
};

// Errors show in the sidebar. How long a successful build took goes in the build details.
function setStatus(text, isError = false) {
    $("status").textContent = isError ? text : "";
    $("status").hidden = !isError;
    if (!isError) $("build-time").textContent = text;
}

// Builds show a preview, so the file itself is made when it's downloaded. The model is still running
// from building that preview, so its geometry is cached, and making the file is mostly encoding it.
// Builds wait until it's done.
$("download").addEventListener("click", async () => {
    if (!downloadable || exporting || building) return;
    const { model: target, parameters } = downloadable;
    exporting = true;
    $("download").disabled = true;
    $("download").textContent = "Preparing…";
    try {
        const result = await builder.export(target.name, parameters);
        if (!result.data) {
            const error = new Error("The model file couldn't be made. See the build details.");
            error.log = result.log;
            throw error;
        }
        const url = URL.createObjectURL(new Blob([result.data], { type: result.fileName.endsWith(".3mf") ? "model/3mf" : "application/octet-stream" }));
        const link = Object.assign(document.createElement("a"), { href: url, download: result.fileName });
        link.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (error) {
        buildLog.show(error.log ?? [error.message]);
        setStatus(error.message, true);
    } finally {
        exporting = false;
        $("download").textContent = "Download Model";
        $("download").disabled = !downloadable;
        if (isReady && builds.get(model.name)?.key !== buildKey(model)) startBuild();
    }
});

// MARK: Viewer

// Without WebGL (turned off, or no usable GPU) there's no preview, but the form, builds and download
// still work
let show;
try {
    show = createViewer();
} catch (error) {
    console.warn("The 3D preview isn't available:", error);
    show = () => {
        $("overlay-text").textContent = "This browser can't show a 3D preview, but the model can still be downloaded.";
        $("progress-bar").parentElement.hidden = true;
    };
}

function createViewer() {
    THREE.Object3D.DEFAULT_UP.set(0, 0, 1);
    const container = $("viewer");
    const renderer = new THREE.WebGLRenderer({ alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    const viewportRenderer = new ViewportRenderer(renderer);
    container.append(renderer.domElement);

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(getComputedStyle(document.documentElement).getPropertyValue("--viewer").trim());
    const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 10000);
    const controlsView = new ViewportControls(camera, renderer.domElement);

    setupLighting(scene, camera, renderer);

    const root = document.documentElement;
    const gridColor = getComputedStyle(root).getPropertyValue("--grid").trim();
    const grid = new ViewportGrid(gridColor);
    scene.add(grid);
    const origin = new OriginAxes();
    scene.add(origin);
    const axisIndicator = new AxisIndicator(container);

    function updateGridColor() {
        grid.material.uniforms.color.value.set(getComputedStyle(root).getPropertyValue("--grid").trim());
        scene.background.set(getComputedStyle(root).getPropertyValue("--viewer").trim());
    }
    // CSS updates the page automatically; the shader's color needs the same changes explicitly.
    matchMedia("(prefers-color-scheme: dark)").addEventListener("change", updateGridColor);
    new MutationObserver(updateGridColor).observe(root, {
        attributes: true, attributeFilter: ["data-theme", "style", "class"],
    });

    let current = null, framed = false;

    function frame(box) {
        controlsView.reset();
        frameIsometric(camera, box, new THREE.Vector3());
    }

    function resize() {
        const { clientWidth: width, clientHeight: height } = container;
        viewportRenderer.setSize(width, height);
        camera.aspect = width / height;
        camera.updateProjectionMatrix();
    }
    new ResizeObserver(resize).observe(container);
    resize();

    renderer.setAnimationLoop((time) => {
        controlsView.update(time);
        camera.updateMatrixWorld();
        grid.updateScale(camera, container.clientWidth, container.clientHeight);
        axisIndicator.update(camera);
        viewportRenderer.render(scene, camera);
    });

    // Frames the model the first time, and again when a different model is shown
    return (data, fileName, isNewModel) => {
        const buffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
        // Parts without a color of their own get the page's model color
        const color = getComputedStyle(document.documentElement).getPropertyValue("--model").trim();
        const object = fileName.endsWith(".cadovapreview") ? readPreview(buffer, color) : read3MF(buffer, color);
        object.traverse((child) => {
            if (child.isMesh) child.geometry = toCreasedNormals(child.geometry, THREE.MathUtils.degToRad(30));
        });
        if (current) {
            scene.remove(current);
            current.traverse((child) => {
                child.geometry?.dispose();
                child.material?.dispose();
            });
        }
        current = object;
        scene.add(object);
        const box = new THREE.Box3().setFromObject(object);
        controlsView.setModel(object, box);
        grid.updateBounds(box);
        origin.visible = !box.isEmpty();
        axisIndicator.show();
        $("overlay").hidden = true;
        if (!framed || isNewModel) { frame(box); framed = true; }
    };
}
