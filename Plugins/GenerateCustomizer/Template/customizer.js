import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { ThreeMFLoader } from "three/addons/loaders/3MFLoader.js";
import { toCreasedNormals } from "three/addons/utils/BufferGeometryUtils.js";
import { fetchModel, listParameters, runModel } from "./runner.js";

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
    if (build?.key === buildKey(model)) {
        display(build);
    } else {
        lastFile = null;
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
            const toggle = document.createElement("span");
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
    writeHash();
    requestBuild();
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

function writeHash() {
    const entries = Object.entries(changed.get(model.name) ?? {});
    if (model !== models[0]) entries.unshift(["model", model.name]);
    history.replaceState(null, "", entries.length ? `#${new URLSearchParams(entries)}` : location.pathname);
}

function humanize(name) {
    const words = name.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[-_]+/g, " ").trim().toLowerCase();
    return words.charAt(0).toUpperCase() + words.slice(1);
}

// MARK: Building

const worker = new Worker(new URL("worker.js", import.meta.url), { type: "module" });
let isReady = false, nextID = 0;
let building = null; // the model and values of the build in progress
const builds = new Map(); // the last build of each model, with the values it was built with
let lastFile = null, shownModel = null;

worker.onmessage = ({ data }) => {
    switch (data.type) {
        case "progress": {
            const megabytes = (bytes) => (bytes / 1e6).toFixed(0);
            $("overlay-text").textContent = data.total
                ? `Loading model… ${megabytes(data.received)} of ${megabytes(data.total)} MB`
                : `Loading model… ${megabytes(data.received)} MB`;
            if (data.total) $("progress-bar").style.width = `${(100 * data.received) / data.total}%`;
            break;
        }
        case "compiling":
            $("overlay-text").textContent = "Preparing model…";
            $("progress-bar").style.width = "100%";
            break;
        case "ready":
            ready(data);
            break;
        case "built":
            finishBuild(data);
            break;
        case "error":
            building = null;
            setStatus(data.message, true);
            $("overlay-text").textContent = data.message;
            break;
    }
};
worker.postMessage({ type: "load", url: new URL("model.wasm", location.href).href });

async function ready({ catalog, log, stackOverflow }) {
    try {
        if (!catalog && stackOverflow) {
            // Listing ran out of stack in the worker, so list (and build) on the main thread instead
            mainThreadModule = WebAssembly.compile(await fetchModel(new URL("model.wasm", location.href).href));
            ({ catalog, log } = await listParameters(await mainThreadModule));
        }
        if (!catalog) throw new Error("The model couldn't list its parameters. See the build log.");
        setUp(catalog);
    } catch (error) {
        $("log").textContent = (log ?? []).join("\n");
        setStatus(error.message, true);
        $("overlay-text").textContent = error.message;
        $("progress-bar").parentElement.hidden = true;
        return;
    }
    isReady = true;
    $("overlay-text").textContent = "Building…";
    requestBuild();
}

let buildTimer;
function requestBuild() {
    clearTimeout(buildTimer);
    buildTimer = setTimeout(startBuild, 120);
}

// Workers get much less native stack than the page itself (probably 512 KB in Safari), and a deep
// model can need more. If a build runs out in the worker, it and every later build run here instead.
let mainThreadModule = null;

function startBuild() {
    if (!isReady || building) return;
    const parameters = valuesFor(model);
    building = { model, parameters, key: JSON.stringify(parameters) };
    $("building").classList.add("visible");
    if (mainThreadModule) {
        buildOnMainThread();
    } else {
        worker.postMessage({ type: "build", id: ++nextID, model: model.name, parameters });
    }
}

async function buildOnMainThread() {
    try {
        if (!mainThreadModule) {
            mainThreadModule = WebAssembly.compile(await fetchModel(new URL("model.wasm", location.href).href));
        }
        // Lets the "Building…" indicator paint before the build blocks the page
        await new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve)));
        finishBuild(await runModel(await mainThreadModule, building.model.name, building.parameters));
    } catch (error) {
        building = null;
        setStatus(String(error?.message ?? error), true);
    }
}

function finishBuild(result) {
    if (result.stackOverflow && !mainThreadModule) {
        console.info("The build ran out of stack in the worker; building on the main thread instead.");
        buildOnMainThread();
        return;
    }
    const finished = building;
    building = null;
    $("building").classList.remove("visible");
    const build = { ...result, key: finished.key };
    builds.set(finished.model.name, build);
    // A build for the model on screen is shown even if its values have changed since, while the
    // next build catches up
    if (finished.model === model) display(build);
    if (builds.get(model.name)?.key !== buildKey(model)) startBuild();
}

function display({ fileName, data, log, exitCode, milliseconds }) {
    $("log").textContent = log.map((line) => line.replace(/^\S+ /, "")).join("\n");
    if (data) {
        lastFile = { name: fileName, data };
        $("download").disabled = false;
        setStatus(`Built in ${Math.round(milliseconds)} ms`);
        show(data, shownModel !== model);
        shownModel = model;
    } else {
        lastFile = null;
        $("download").disabled = true;
        setStatus(exitCode === 0 ? "The model built to nothing." : "The model failed to build. See the build log.", true);
    }
}

function setStatus(text, isError = false) {
    $("status").textContent = text;
    $("status").classList.toggle("error", isError);
}

$("download").addEventListener("click", () => {
    if (!lastFile) return;
    const url = URL.createObjectURL(new Blob([lastFile.data], { type: "model/3mf" }));
    const link = Object.assign(document.createElement("a"), { href: url, download: lastFile.name });
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
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
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    container.append(renderer.domElement);

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 10000);
    const controlsView = new OrbitControls(camera, renderer.domElement);
    controlsView.enableDamping = true;

    scene.add(new THREE.HemisphereLight(0xffffff, 0x8a8577, 2.2));
    const keyLight = new THREE.DirectionalLight(0xffffff, 1.8);
    keyLight.position.set(1, -1.5, 2);
    camera.add(keyLight);
    scene.add(camera);

    const gridColor = getComputedStyle(document.documentElement).getPropertyValue("--text").trim();
    const grid = new THREE.GridHelper(400, 40, gridColor, gridColor);
    grid.rotation.x = Math.PI / 2;
    grid.material.transparent = true;
    grid.material.opacity = 0.08;
    scene.add(grid);

    const loader = new ThreeMFLoader();
    let current = null, framed = false;

    function frame() {
        const box = new THREE.Box3().setFromObject(current);
        const size = box.getSize(new THREE.Vector3()).length();
        const center = box.getCenter(new THREE.Vector3());
        controlsView.target.copy(center);
        camera.position.copy(center).add(new THREE.Vector3(0.6, -1.0, 0.75).normalize().multiplyScalar(size * 1.5));
        camera.near = size / 100;
        camera.far = size * 100;
        camera.updateProjectionMatrix();
    }

    function resize() {
        const { clientWidth: width, clientHeight: height } = container;
        renderer.setSize(width, height, false);
        camera.aspect = width / height;
        camera.updateProjectionMatrix();
    }
    new ResizeObserver(resize).observe(container);
    resize();

    renderer.setAnimationLoop(() => {
        controlsView.update();
        renderer.render(scene, camera);
    });

    // Frames the model the first time, and again when a different model is shown
    return (data, isNewModel) => {
        const buffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
        const object = loader.parse(buffer);
        const color = getComputedStyle(document.documentElement).getPropertyValue("--model").trim();
        object.traverse((child) => {
            if (!child.isMesh) return;
            child.geometry = toCreasedNormals(child.geometry, THREE.MathUtils.degToRad(30));
            child.material = new THREE.MeshStandardMaterial({ color, roughness: 0.65, metalness: 0 });
        });
        if (current) {
            scene.remove(current);
            current.traverse((child) => child.geometry?.dispose());
        }
        current = object;
        scene.add(object);
        $("overlay").hidden = true;
        if (!framed || isNewModel) { frame(); framed = true; }
    };
}
