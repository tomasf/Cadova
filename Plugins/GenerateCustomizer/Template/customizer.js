import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { ThreeMFLoader } from "three/addons/loaders/3MFLoader.js";
import { toCreasedNormals } from "three/addons/utils/BufferGeometryUtils.js";
import { fetchModel, listParameters, runModel } from "./runner.js";

const $ = (id) => document.getElementById(id);

// The model and its parameters come from the model itself, listed once it has loaded
let model, defaults, values;

// MARK: Form

const form = $("parameters");
const controls = new Map();

// Sets the page up for the model chosen by the page's cadova-model meta tag, or else the first model
// that has parameters
function setUp(catalog) {
    const chosen = document.querySelector('meta[name="cadova-model"]')?.content;
    model = catalog.models.find((m) => chosen ? m.name === chosen : m.parameters.length > 0);
    if (!model) throw new Error(chosen ? `The model "${chosen}" wasn't found.` : "No model has parameters to customize.");

    const title = model.title ?? humanize(model.name.split("/").pop());
    document.title = `${title} customizer`;
    $("title").textContent = title;
    if (model.description) $("subtitle").textContent = model.description;

    defaults = Object.fromEntries(model.parameters.map((p) => [p.name, p.default]));
    values = { ...defaults, ...valuesFromHash() };
    for (const parameter of model.parameters) form.append(field(parameter));
}

function field(parameter) {
    const element = document.createElement("div");
    element.className = "field";
    const id = `parameter-${parameter.name}`;
    const head = document.createElement("div");
    head.className = "field-head";
    const label = document.createElement("label");
    label.htmlFor = id;
    label.textContent = humanize(parameter.name);
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
            input.addEventListener("change", () => update(parameter.name, input.checked));
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
                    button.addEventListener("click", () => { setValue(option); update(parameter.name, option); });
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
                select.addEventListener("change", () => update(parameter.name, select.value));
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
                range.setAttribute("aria-label", humanize(parameter.name));
                range.addEventListener("input", () => {
                    number.value = range.value;
                    update(parameter.name, Number(range.value));
                });
                control.append(range);
            }
            number.addEventListener("change", () => {
                if (number.value === "" || !number.checkValidity()) {
                    number.value = values[parameter.name];
                    return;
                }
                if (range) range.value = number.value;
                update(parameter.name, Number(number.value));
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
            input.addEventListener("change", () => update(parameter.name, input.value));
            control.append(input);
            setValue = (value) => { input.value = value; };
        }
    }
    setValue(values[parameter.name]);
    controls.set(parameter.name, setValue);
    return element;
}

function update(name, value) {
    values[name] = value;
    writeHash();
    requestBuild();
}

$("reset").addEventListener("click", () => {
    Object.assign(values, defaults);
    for (const [name, setValue] of controls) setValue(values[name]);
    writeHash();
    requestBuild();
});

// Values that differ from the defaults are kept in the address, so a configured model can be shared
function valuesFromHash() {
    const result = {};
    for (const [name, raw] of new URLSearchParams(location.hash.slice(1))) {
        const parameter = model.parameters.find((p) => p.name === name);
        if (!parameter) continue;
        result[name] = parameter.type === "boolean" ? raw === "true"
            : ["integer", "number", "angle"].includes(parameter.type) ? Number(raw) : raw;
    }
    return result;
}

function writeHash() {
    const changed = Object.entries(values).filter(([name, value]) => value !== defaults[name]);
    history.replaceState(null, "", changed.length ? `#${new URLSearchParams(changed)}` : location.pathname);
}

function humanize(name) {
    const words = name.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[-_]+/g, " ").trim().toLowerCase();
    return words.charAt(0).toUpperCase() + words.slice(1);
}

// MARK: Building

const worker = new Worker(new URL("worker.js", import.meta.url), { type: "module" });
let isReady = false, building = false, pending = false, nextID = 0;
let lastFile = null;

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
            building = false;
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
    if (!isReady) return;
    if (building) { pending = true; return; }
    building = true;
    pending = false;
    $("building").classList.add("visible");
    if (mainThreadModule) {
        buildOnMainThread();
    } else {
        worker.postMessage({ type: "build", id: ++nextID, model: model.name, parameters: { ...values } });
    }
}

async function buildOnMainThread() {
    try {
        if (!mainThreadModule) {
            mainThreadModule = WebAssembly.compile(await fetchModel(new URL("model.wasm", location.href).href));
        }
        // Lets the "Building…" indicator paint before the build blocks the page
        await new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve)));
        finishBuild(await runModel(await mainThreadModule, model.name, { ...values }));
    } catch (error) {
        building = false;
        setStatus(String(error?.message ?? error), true);
    }
}

function finishBuild(result) {
    if (result.stackOverflow && !mainThreadModule) {
        console.info("The build ran out of stack in the worker; building on the main thread instead.");
        buildOnMainThread();
        return;
    }
    const { fileName, data, log, exitCode, milliseconds } = result;
    building = false;
    $("building").classList.remove("visible");
    $("log").textContent = log.map((line) => line.replace(/^\S+ /, "")).join("\n");
    if (data) {
        lastFile = { name: fileName, data };
        $("download").disabled = false;
        setStatus(`Built in ${Math.round(milliseconds)} ms`);
        show(data);
    } else {
        setStatus(exitCode === 0 ? "The model built to nothing." : "The model failed to build. See the build log.", true);
    }
    if (pending) startBuild();
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

    return (data) => {
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
        if (!framed) { frame(); framed = true; }
    };
}
