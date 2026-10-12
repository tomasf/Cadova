"""Tests a generated web customizer in real browsers.

Generate the fixture's customizer first, then run this with the browser engines to test:

    cd Tests/Customizer/Fixture
    swift package --allow-network-connections all:443 --allow-writing-to-package-directory generate-customizer
    python3 ../test_customizer.py chromium webkit

It serves the customizer locally, loads the page, and checks that the form matches the models'
parameters, that changing them through the URL and through the form rebuilds the model, that each model's
tab keeps its own values, and that the downloaded 3MF reflects each change.
"""

import base64
import functools
import http.server
import json
import re
import sys
import threading
import zipfile
from io import BytesIO
from pathlib import Path

from playwright.sync_api import Error as PlaywrightError, expect, sync_playwright

CUSTOMIZER = Path(__file__).parent / "Fixture" / "Customizer"
TIMEOUT = 180_000  # loading and compiling the model can be slow on CI machines


class Mesh:
    """The vertices and triangle count of the first mesh in a 3MF file."""

    def __init__(self, data):
        self.data = data
        with zipfile.ZipFile(BytesIO(data)) as archive:
            model = archive.read("3D/3dmodel.model").decode()
        self.vertices = [
            tuple(float(value) for value in match)
            for match in re.findall(r'<vertex x="([^"]+)" y="([^"]+)" z="([^"]+)"', model)
        ]
        self.triangles = len(re.findall(r"<triangle ", model))
        if not self.vertices or not self.triangles:
            raise AssertionError("The 3MF file has no mesh")

    def extent(self, axis):
        values = [vertex[axis] for vertex in self.vertices]
        return max(values) - min(values)


class CustomizerPage:
    def __init__(self, page, base_url):
        self.page = page
        self.base_url = base_url
        self.errors = []
        page.on("pageerror", lambda error: self.errors.append(str(error)))

    def open(self, hash=""):
        # Going to the same page with only a different hash wouldn't reload it
        self.page.goto("about:blank")
        self.page.goto(f"{self.base_url}/index.html{hash}")
        self.wait_for_build()

    def wait_for_build(self):
        # A finished build puts its time in the build details; a failure shows an error in the sidebar
        self.page.wait_for_function("""() =>
            document.getElementById("build-time").textContent.startsWith("Built in")
                || document.getElementById("status").textContent !== ""
        """, timeout=TIMEOUT)
        error = self.page.locator("#status").text_content()
        if error:
            log = self.page.locator("#log").text_content()
            raise AssertionError(f"The build failed: {error}\n{log}")

    def rebuild(self, action):
        """Runs an action that should rebuild the model, and waits for the new build."""
        self.page.evaluate("document.getElementById('build-time').textContent = ''")
        action()
        self.wait_for_build()

    def number_field(self, label):
        return self.page.get_by_role("spinbutton", name=label)

    def set_number(self, label, value):
        field = self.number_field(label)
        field.fill(value)
        field.blur()  # number fields report a change when they lose focus

    def viewer_materials(self, mesh):
        """The materials the page's viewer reads from a 3MF file, one for each mesh it makes."""
        return self.page.evaluate("""async (encoded) => {
            const { read3MF } = await import("./threemf.js");
            const bytes = Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0));
            return read3MF(bytes.buffer, getComputedStyle(document.documentElement).getPropertyValue("--model").trim()).children.map(({ material }) => ({
                color: material.color.getHexString("srgb"), metalness: material.metalness,
                roughness: material.roughness, opacity: material.opacity,
            }));
        }""", base64.b64encode(mesh.data).decode())

    def download(self):
        with self.page.expect_download(timeout=TIMEOUT) as download:
            self.page.locator("#download").click()
        return Mesh(Path(download.value.path()).read_bytes())


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def copyfile(self, source, output):
        try:
            super().copyfile(source, output)
        except (BrokenPipeError, ConnectionResetError):
            pass  # cancelling a worker can stop a download midway


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def test(browser, base_url):
    page = CustomizerPage(browser.new_page(), base_url)

    # The form comes from the model's own parameter list
    page.open()
    expect(page.page.locator("#overlay")).to_be_hidden()  # the preview shows the model
    expect(page.page.locator("#title")).to_have_text("Test Parts")
    expect(page.page.locator("#subtitle")).to_have_text("Parts for testing the web customizer.")
    expect(page.page.get_by_role("tab", name="Test Plate")).to_have_attribute("aria-selected", "true")
    expect(page.page.locator(".model-description")).to_have_text("A plate with holes.")
    for name in ["Width", "Holes"]:
        expect(page.number_field(name)).to_be_attached()
    expect(page.page.get_by_role("checkbox", name="Thick")).to_be_attached()
    expect(page.page.get_by_role("button", name="Rounded")).to_have_attribute("aria-pressed", "true")
    default = page.download()
    check(abs(default.extent(0) - 40) < 0.01, f"Default width is {default.extent(0)}, expected 40")
    check(abs(default.extent(2) - 3) < 0.01, f"Default thickness is {default.extent(2)}, expected 3")
    # The depth comes from a resource file in the package, which the customizer has to provide
    check(abs(default.extent(1) - 32) < 0.01, f"Depth is {default.extent(1)}, expected 32 from the package's resource")

    # The whole switch is clickable, not just a checkbox-sized spot in its corner as WebKit once had it
    switch = page.page.locator(".toggle").bounding_box()
    page.page.evaluate("document.getElementById('build-time').textContent = ''")
    page.page.mouse.click(switch["x"] + switch["width"] * 0.85, switch["y"] + switch["height"] * 0.8)
    expect(page.page.get_by_role("checkbox", name="Thick")).to_be_checked()
    page.wait_for_build()
    thick = page.download()
    check(abs(thick.extent(2) - 6) < 0.01, f"Thickness after turning on the switch is {thick.extent(2)}, expected 6")

    # Values in the URL hash override the defaults
    page.open("#Width=80&Thick=true")
    expect(page.number_field("Width")).to_have_value("80")
    changed = page.download()
    check(abs(changed.extent(0) - 80) < 0.01, f"Width from the URL is {changed.extent(0)}, expected 80")
    check(abs(changed.extent(2) - 6) < 0.01, f"Thickness from the URL is {changed.extent(2)}, expected 6")

    # Changing a value in the form rebuilds the model and updates the URL
    page.rebuild(lambda: page.page.get_by_role("button", name="Square").click())
    expect(page.page).to_have_url(re.compile(r"Corners=square"))
    square = page.download()
    check(square.triangles < changed.triangles,
          f"Square corners should need fewer triangles than rounded ones ({square.triangles} vs {changed.triangles})")
    check(abs(square.extent(0) - 80) < 0.01, "Changing the corners lost the width")

    page.rebuild(lambda: page.set_number("Holes", "0"))
    no_holes = page.download()
    check(no_holes.triangles < square.triangles,
          f"Removing the holes should remove triangles ({no_holes.triangles} vs {square.triangles})")

    # Dragging a slider makes many changes in a row. Safari throws if the address changes more than
    # 100 times in 10 seconds, which once stopped the model from updating.
    page.page.evaluate("document.getElementById('build-time').textContent = ''")
    page.page.evaluate("""() => {
        const range = document.querySelector('input[type="range"][aria-label="Width"]');
        for (let i = 0; i <= 150; i++) {
            range.value = i < 150 ? 10 + (i % 90) : 55;
            range.dispatchEvent(new Event("input", { bubbles: true }));
        }
    }""")
    check(not page.errors, f"Dragging a slider caused errors: {page.errors}")
    page.wait_for_build()
    expect(page.number_field("Width")).to_have_value("55")
    expect(page.page).to_have_url(re.compile(r"Width=55"))
    dragged = page.download()
    check(abs(dragged.extent(0) - 55) < 0.01, f"Width after dragging is {dragged.extent(0)}, expected 55")

    check(not page.errors, f"The page had errors: {page.errors}")


def test_tabs(browser, base_url):
    """Each model with parameters gets a tab, and each keeps its own values, even for parameters with
    the same label."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open("#Width=80")
    plate = page.download()
    check(abs(plate.extent(0) - 80) < 0.01, f"Plate width is {plate.extent(0)}, expected 80")

    # The spacer's Width is its own parameter, so it keeps its default
    page.rebuild(lambda: page.page.get_by_role("tab", name="Spacer").click())
    expect(page.page.get_by_role("tab", name="Spacer")).to_have_attribute("aria-selected", "true")
    expect(page.number_field("Width")).to_have_value("20")
    expect(page.number_field("Height")).to_be_attached()
    expect(page.page.locator(".model-description")).to_have_count(0)  # it has no description of its own
    expect(page.page).to_have_url(re.compile(r"#model=spacer$"))
    spacer = page.download()
    check(spacer.vertices != plate.vertices, "Switching tabs didn't build the other model")
    check(abs(spacer.extent(0) - 20) < 0.01, f"Spacer diameter is {spacer.extent(0)}, expected 20")
    check(abs(spacer.extent(2) - 5) < 0.01, f"Spacer height is {spacer.extent(2)}, expected 5")
    expected = [{"color": "3366cc", "metalness": 0.5, "roughness": 0.3, "opacity": 1}]
    check(page.viewer_materials(spacer) == expected,
          f"The viewer reads the spacer's materials as {page.viewer_materials(spacer)}, expected {expected}")

    # Changing the spacer's width leaves the plate's alone
    page.rebuild(lambda: page.set_number("Width", "30"))
    spacer = page.download()
    check(abs(spacer.extent(0) - 30) < 0.01, f"Spacer diameter is {spacer.extent(0)}, expected 30")
    page.rebuild(lambda: page.page.get_by_role("tab", name="Test Plate").click())
    expect(page.number_field("Width")).to_have_value("80")
    expect(page.page).to_have_url(re.compile(r"#Width=80$"))
    plate = page.download()
    check(abs(plate.extent(0) - 80) < 0.01, f"Plate width after changing the spacer's is {plate.extent(0)}, expected 80")

    # A link opens the same tab with the same values
    page.open("#model=spacer&Width=25")
    expect(page.page.get_by_role("tab", name="Spacer")).to_have_attribute("aria-selected", "true")
    spacer = page.download()
    check(abs(spacer.extent(0) - 25) < 0.01, f"Spacer diameter from the URL is {spacer.extent(0)}, expected 25")
    check(not page.errors, f"The page had errors: {page.errors}")


def test_single_model(browser, base_url):
    """A page made for one model (generate-customizer --model) has no tabs."""
    page = CustomizerPage(browser.new_page(), base_url)

    def add_meta_tag(route):
        response = route.fetch()
        tag = '<meta name="cadova-model" content="spacer">\n<meta name="viewport"'
        route.fulfill(response=response, body=response.text().replace('<meta name="viewport"', tag, 1))

    page.page.route("**/index.html*", add_meta_tag)
    page.open()
    expect(page.page.locator("#models")).to_be_hidden()
    expect(page.page.locator("#title")).to_have_text("Test Parts")  # the spacer's title comes from the project
    expect(page.number_field("Height")).to_be_attached()
    spacer = page.download()
    check(abs(spacer.extent(0) - 20) < 0.01, f"Spacer diameter is {spacer.extent(0)}, expected 20")
    check(not page.errors, f"The page had errors: {page.errors}")


def test_without_webgl(browser, base_url):
    """Without WebGL there's no preview, but building and downloading still work."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open()
    expect(page.page.locator("#overlay-text")).to_contain_text("can't show a 3D preview")
    mesh = page.download()
    check(abs(mesh.extent(0) - 40) < 0.01, f"Width without WebGL is {mesh.extent(0)}, expected 40")
    expect(page.page.locator("#axis-indicator")).to_have_count(0)
    check(not page.errors, f"The page had errors without WebGL: {page.errors}")


def test_grid(browser, base_url):
    """Render the grid itself to check its circular fade and bounds away from the origin."""
    page = CustomizerPage(browser.new_page(), base_url)
    shader_errors = []
    page.page.on("console", lambda message: shader_errors.append(message.text)
                 if message.type == "error" and "WebGLProgram" in message.text else None)
    page.open()
    result = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { ViewportGrid } = await import("./grid.js");
        const { ViewportRenderer } = await import("./rendering.js");
        const renderer = new THREE.WebGLRenderer({ preserveDrawingBuffer: true });
        const viewport = new ViewportRenderer(renderer);
        viewport.setSize(800, 800);
        const scene = new THREE.Scene();
        scene.background = new THREE.Color("#ecebe6");
        const camera = new THREE.OrthographicCamera(-180, 180, 180, -180, 0.1, 1000);
        camera.up.set(0, 1, 0);
        camera.position.set(0, 0, 400);
        camera.lookAt(0, 0, 0);
        camera.updateMatrixWorld();
        const grid = new ViewportGrid("#1d1d1b");
        grid.updateBounds(new THREE.Box3(new THREE.Vector3(-50, -50, 0), new THREE.Vector3(50, 50, 20)));
        grid.updateScale(camera, 800, 800);
        // Fix the disk size here to isolate the shader fade from the camera-following footprint.
        grid.setFootprint(grid.modelCenter, grid.modelBaseRadius);
        scene.add(grid);
        viewport.render(scene, camera);
        const gl = renderer.getContext();
        function sample(x, y) {
            const pixel = new Uint8Array(4);
            const point = new THREE.Vector3(x, y, 0).project(camera);
            gl.readPixels(Math.floor((point.x + 1) * 400), Math.floor((point.y + 1) * 400),
                1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
            return [...pixel];
        }
        const result = { inner: sample(0, 50), rim: sample(0, 110),
            corner: sample(100, 100), outside: sample(150, 150) };
        grid.updateBounds(new THREE.Box3(new THREE.Vector3(200, -80, 0), new THREE.Vector3(500, 20, 30)));
        result.center = grid.position.toArray();
        result.coversBounds = [new THREE.Vector3(200, -80, 0), new THREE.Vector3(500, 20, 0)]
            .every(point => point.distanceTo(grid.position) < grid.material.uniforms.radius.value);
        viewport.dispose();
        renderer.dispose();
        grid.geometry.dispose();
        grid.material.dispose();
        return result;
    }''')
    contrast = lambda pixel: sum(abs(a - b) for a, b in zip(pixel[:3], result["outside"][:3]))
    check(contrast(result["inner"]) > contrast(result["rim"]) > 0, f"The grid doesn't fade at its rim: {result}")
    check(contrast(result["corner"]) == 0, f"The grid's square corners should be invisible: {result}")
    check(result["center"] == [350, -30, 0] and result["coversBounds"], f"The grid doesn't follow translated bounds: {result}")
    check(not shader_errors and not page.errors, f"Grid rendering errors: {shader_errors + page.errors}")
    page.page.context.close()


def test_grid_theme(browser, base_url):
    """The native-style viewport stays dark across page themes, and grid overrides update live."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.page.emulate_media(color_scheme="light")
    page.open()
    build_time = page.page.locator("#build-time").text_content()
    # Observe the actual grid rendered by the page, without exposing viewer state in product code.
    page.page.evaluate('''async () => {
        const THREE = await import("three");
        const updateMatrixWorld = THREE.Camera.prototype.updateMatrixWorld;
        THREE.Camera.prototype.updateMatrixWorld = function(...args) {
            updateMatrixWorld.apply(this, args);
            const grid = this.parent?.getObjectByName("Grid");
            if (grid) window.gridThemeColor = grid.material.uniforms.color.value.getHexString();
        };
    }''')

    def expect_color(hex):
        page.page.wait_for_function("hex => window.gridThemeColor === hex", arg=hex, timeout=5000)

    expect_color("ffffff")
    page.page.emulate_media(color_scheme="dark")
    expect_color("ffffff")
    page.page.emulate_media(color_scheme="light")
    expect_color("ffffff")
    page.page.evaluate('document.documentElement.dataset.theme = "dark"')
    expect_color("ffffff")
    page.page.emulate_media(color_scheme="dark")
    page.page.evaluate('document.documentElement.dataset.theme = "light"')
    expect_color("ffffff")
    page.page.evaluate('delete document.documentElement.dataset.theme')
    expect_color("ffffff")
    page.page.evaluate('document.documentElement.style.setProperty("--grid", "#123456")')
    expect_color("123456")
    page.page.evaluate('document.documentElement.style.removeProperty("--grid")')
    expect_color("ffffff")
    check(page.page.locator("main").evaluate("element => getComputedStyle(element).backgroundColor") == "rgb(13, 13, 13)",
          "The viewer background changed with the page theme")
    check(page.page.locator("#build-time").text_content() == build_time, "Changing the theme rebuilt the model")
    expect(page.page.locator("#download")).to_be_enabled()
    check(not page.errors, f"Theme changes caused page errors: {page.errors}")
    page.page.context.close()


def test_viewer_defaults(browser, base_url):
    """Compare framing with values generated by Cadova Viewer's actual CameraUtils.swift."""
    page = CustomizerPage(browser.new_page(viewport={"width": 1280, "height": 900}), base_url)
    page.open()
    page.page.evaluate('''async () => {
        const THREE = await import("three");
        const update = THREE.Camera.prototype.updateMatrixWorld;
        THREE.Camera.prototype.updateMatrixWorld = function(...args) {
            update.apply(this, args);
            const model = this.parent?.children.find(child => child.isGroup);
            if (!model || !this.parent.getObjectByName("Grid")) return;
            const center = new THREE.Box3().setFromObject(model).getCenter(new THREE.Vector3());
            const offset = this.position.clone().sub(center);
            const materials = [];
            model.traverse(child => { if (child.isMesh) materials.push({
                color: child.material.color.getHexString(), roughness: child.material.roughness,
            }); });
            window.viewerDefaults = { fov: this.fov, axis: offset.clone().normalize().toArray(),
                distance: offset.length(), materials };
        };
    }''')
    page.page.wait_for_function("window.viewerDefaults")
    actual = page.page.evaluate("window.viewerDefaults")
    axis = [-0.6324573569857368, -0.6324573569857368, 0.44720843371881136]
    check(actual["fov"] == 30 and all(abs(a - b) < 1e-6 for a, b in zip(actual["axis"], axis)),
          f"The initial camera doesn't match Cadova Viewer's isometric preset: {actual}")
    check(abs(actual["distance"] - 139.40583355983588) < 0.0001, f"Incorrect default framing: {actual}")
    check(actual["materials"] and all(material == {"color": "ffffff", "roughness": 0.9}
                                     for material in actual["materials"]), f"Incorrect default material: {actual}")
    check(page.page.locator("main").evaluate("element => getComputedStyle(element).backgroundColor") == "rgb(13, 13, 13)",
          "The background doesn't match Cadova Viewer's 5% gray")
    # Native reference distances include narrow/tall views and bounds far from the origin.
    cases = [
        {"min": [0, 0, 0], "max": [40, 32, 3], "aspect": 920 / 900, "distance": 139.40583355983588},
        {"min": [200, -80, -30], "max": [500, 20, 180], "aspect": 0.5, "distance": 1583.3823071958},
        {"min": [-20, -10, 0], "max": [20, 10, 300], "aspect": 2, "distance": 804.171269348275},
    ]
    distances = page.page.evaluate('''async cases => {
        const THREE = await import("three");
        const { frameIsometric } = await import("./camera.js");
        return cases.map(({ min, max, aspect }) => {
            const camera = new THREE.PerspectiveCamera(30, aspect);
            camera.up.set(0, 0, 1);
            const target = new THREE.Vector3();
            frameIsometric(camera, new THREE.Box3(new THREE.Vector3(...min), new THREE.Vector3(...max)), target);
            return camera.position.distanceTo(target);
        });
    }''', cases)
    # Native framing builds its basis in Float; allow its rounding at translated/large bounds.
    check(all(abs(distance - case["distance"]) < case["distance"] * 1e-5 for distance, case in zip(distances, cases)),
          f"Framing differs from the native reference: {distances}")
    check(not page.errors, f"Viewer default errors: {page.errors}")
    page.page.context.close()


def test_grid_navigation(browser, base_url):
    """Check the native grid's pan/zoom footprint, metric density, and grazing-angle bounds."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open()
    result = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { ViewportGrid } = await import("./grid.js");
        const grid = new ViewportGrid("white");
        grid.updateBounds(new THREE.Box3(new THREE.Vector3(-50, -50, 0), new THREE.Vector3(50, 50, 20)));
        const camera = new THREE.PerspectiveCamera(30, 1, 0.001, 100000);
        camera.up.set(0, 1, 0);
        function view(position, target) {
            camera.position.set(...position);
            camera.lookAt(...target);
            camera.updateMatrixWorld();
            grid.updateScale(camera, 400, 400);
            return { center: grid.position.toArray(), radius: grid.material.uniforms.radius.value };
        }
        const start = view([0, 0, 400], [0, 0, 0]);
        const pan = view([500, -300, 400], [500, -300, 0]);
        const smallPan = view([501, -300, 400], [501, -300, 0]);
        const zoom = view([501, -300, 100], [501, -300, 0]);
        grid.updateBounds(new THREE.Box3(new THREE.Vector3(200, -80, 0), new THREE.Vector3(500, 20, 30)));
        const far = view([10000, -10000, 10000], [10000, -10000, 0]);
        const blend = view([1000, 1000, 4440], [1000, 1000, 0]);
        camera.up.set(0, 0, 1);
        const horizon = view([350, -500, 0], [350, -30, 0]);
        const near = view([350, -30, 0.01], [350, -30, 0]);
        const ortho = new THREE.OrthographicCamera(-100, 100, 100, -100, 0.1, 1000);
        ortho.up.set(0, 1, 0);
        ortho.position.set(0, 0, -400);
        ortho.lookAt(0, 0, 0);
        ortho.updateMatrixWorld();
        grid.updateScale(ortho, 400, 400);
        const hiddenBelow = !grid.visible;
        ortho.position.z = 400;
        ortho.lookAt(0, 0, 0);
        ortho.updateMatrixWorld();
        grid.updateScale(ortho, 400, 400);
        const visibleAbove = grid.visible;
        const coarse = grid.material.uniforms.spacing.value;
        const fineOpacity = grid.material.uniforms.fineOpacity.value;
        ortho.zoom = 10;
        ortho.updateProjectionMatrix();
        grid.updateScale(ortho, 400, 400);
        const zoomedCoarse = grid.material.uniforms.spacing.value;
        grid.geometry.dispose();
        grid.material.dispose();
        return { start, pan, smallPan, zoom, far, blend, horizon, near, hiddenBelow, visibleAbove,
            coarse, fineOpacity, zoomedCoarse };
    }''')
    for name, center, radius in [
        ("start", [0, 0, 0], 800), ("pan", [500, -300, 0], 800), ("smallPan", [500, -300, 0], 800),
        ("zoom", [501, -300, 0], 200), ("far", [350, -30, 0], 12000),
        ("blend", [675, 485, 0], 8880), ("horizon", [350, -30, 0], 940), ("near", [350, -30, 0], 48),
    ]:
        actual = result[name]
        check(all(abs(a - b) < 0.001 for a, b in zip(actual["center"], center))
              and abs(actual["radius"] - radius) < 0.001, f"Unexpected grid footprint for {name}: {actual}")
    check(result["hiddenBelow"] and result["visibleAbove"], f"Incorrect orthographic grid visibility: {result}")
    check(result["coarse"] == 100 and result["zoomedCoarse"] == 10 and abs(result["fineOpacity"] - 0.30103) < 0.00001,
          f"Incorrect metric grid density: {result}")
    check(not page.errors, f"Grid navigation errors: {page.errors}")
    page.page.context.close()


def test_line_rendering(browser, base_url):
    """Keep the faint grid and antialiased origin consistent with SceneKit's rendered pixels."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open()
    result = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { ViewportGrid } = await import("./grid.js");
        const { OriginAxes } = await import("./axes.js");
        const { ViewportRenderer } = await import("./rendering.js");
        function render(fallback) {
            const renderer = new THREE.WebGLRenderer({ preserveDrawingBuffer: true });
            if (fallback) {
                const has = renderer.extensions.has.bind(renderer.extensions);
                renderer.extensions.has = name => name === "EXT_color_buffer_float" ? false : has(name);
            }
            const viewport = new ViewportRenderer(renderer);
            viewport.setSize(400, 400);
            const scene = new THREE.Scene();
            scene.background = new THREE.Color("#0d0d0d");
            const camera = new THREE.OrthographicCamera(-100, 100, 100, -100, 0.1, 1000);
            camera.up.set(0, 1, 0);
            camera.position.set(0, 0, 400);
            camera.lookAt(0, 0, 0);
            camera.updateMatrixWorld();
            const grid = new ViewportGrid("white");
            grid.updateBounds(new THREE.Box3(new THREE.Vector3(-100, -100, 0), new THREE.Vector3(100, 100, 20)));
            grid.setFootprint(new THREE.Vector3(), 400);
            grid.material.uniforms.spacing.value = 20;
            grid.material.uniforms.fineOpacity.value = 0;
            scene.add(grid);
            viewport.render(scene, camera);
            const gl = renderer.getContext();
            function pixel(x, y) {
                const color = new Uint8Array(4);
                gl.readPixels(x, y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, color);
                return color[0];
            }
            // x = 20 is a grid line; y = 25 avoids a crossing. Half a pixel of white at 5%
            // alpha over 5% sRGB gray gives about 47/255 after linear-light blending.
            const gridProfile = [238, 239, 240, 241].map(x => pixel(x, 250));
            grid.visible = false;
            const origin = new OriginAxes();
            origin.visible = true;
            scene.add(origin);
            viewport.render(scene, camera);
            // The native renderer produces [13, 74, 74, 13] for the centered gray origin line.
            const originProfile = [198, 199, 200, 201].map(x => pixel(x, 250));
            origin.geometry.dispose();
            origin.material.dispose();
            grid.geometry.dispose();
            grid.material.dispose();
            viewport.dispose();
            renderer.dispose();
            return { gridProfile, originProfile };
        }
        return { normal: render(false), fallback: render(true) };
    }''')
    for mode, pixels in result.items():
        check(pixels["gridProfile"][0] == 13 and pixels["gridProfile"][3] == 13
              and all(43 <= value <= 51 for value in pixels["gridProfile"][1:3]),
              f"The {mode} grid no longer matches native contrast: {pixels}")
        check(all(abs(actual - expected) <= 3 for actual, expected in zip(pixels["originProfile"], [13, 74, 74, 13])),
              f"The {mode} origin no longer matches native antialiasing: {pixels}")
    check(not page.errors, f"Line rendering errors: {page.errors}")
    page.page.context.close()


def test_sharp_edges(browser, base_url):
    """Outline geometric creases across material splits, while hiding rear and smooth edges."""
    page = CustomizerPage(browser.new_page(), base_url)
    shader_errors = []
    page.page.on("console", lambda message: shader_errors.append(message.text) if message.type == "error" else None)
    page.open()
    result = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { read3MF } = await import("./threemf.js");
        const { createSharpEdges } = await import("./edges.js");
        const { zipSync, strToU8 } = await import("three/addons/libs/fflate.module.js");
        const { ViewportRenderer } = await import("./rendering.js");
        const vertices = [[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]];
        const triangles = [[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]];
        function cube(semantic = "solid", dark = false) {
            // Alternating face materials also split every coplanar triangle diagonal.
            const xml = `<model xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
                xmlns:m="http://schemas.microsoft.com/3dmanufacturing/material/2015/02" xmlns:c="https://cadova.org/3mf">
                <resources><m:colorgroup id="1"><m:color color="${dark ? '#101010' : '#ffffff'}"/><m:color color="#ffffff"/></m:colorgroup>
                <object id="2"><mesh><vertices>${vertices.map(([x,y,z]) => `<vertex x="${x}" y="${y}" z="${z}"/>`).join('')}</vertices>
                <triangles>${triangles.map(([a,b,c], i) => `<triangle v1="${a}" v2="${b}" v3="${c}" pid="1" p1="${i % 2}"/>`).join('')}</triangles></mesh></object>
                <object id="3"><components><component objectid="2" transform="1 0 0 0 1 0 0 0 1 10 20 30"/></components></object></resources>
                <build><item objectid="3" c:semantic="${semantic}"/></build></model>`;
            return read3MF(zipSync({"3D/3dmodel.model": strToU8(xml)}).buffer, "white");
        }
        function lines(group) {
            const result = [];
            group.traverse(child => { if (child.isLineSegments) result.push(child); });
            return result;
        }
        const model = cube();
        const outline = lines(model)[0];
        model.updateMatrixWorld(true);
        const bounds = new THREE.Box3().setFromObject(outline);
        const darkColors = lines(cube("solid", true))[0].geometry.attributes.color.array;
        const white = new THREE.MeshBasicMaterial({color: "white"});
        function crease(degrees, third = false) {
            const angle = THREE.MathUtils.degToRad(degrees);
            const positions = new Float32Array([0,0,0, 1,0,0, 0,1,0, 0,-Math.cos(angle),Math.sin(angle), 0,0,1]);
            const indices = new Uint32Array(third ? [0,1,2,1,0,3,0,1,4] : [0,1,2,1,0,3]);
            return createSharpEdges(positions, indices, [white,white,white]);
        }
        const open = createSharpEdges(new Float32Array([0,0,0,1,0,0,0,1,0]), new Uint32Array([0,1,2]), [white]);
        const degenerate = createSharpEdges(new Float32Array([0,0,0,1,0,0,0,1,0]), new Uint32Array([0,1,2,1,0,0]), [white,white]);

        const renderer = new THREE.WebGLRenderer({ preserveDrawingBuffer: true });
        const viewport = new ViewportRenderer(renderer);
        viewport.setSize(128,128);
        const scene = new THREE.Scene();
        scene.background = new THREE.Color("white");
        const camera = new THREE.OrthographicCamera(-2,2,2,-2,0.1,100);
        camera.up.set(0,1,0);
        camera.position.set(0,0,10);
        camera.lookAt(0,0,0);
        camera.updateMatrixWorld();
        const surface = new THREE.Mesh(new THREE.PlaneGeometry(3,3), white);
        surface.position.z = 1;
        scene.add(surface);
        const edge = crease(90);
        scene.add(edge);
        function darkPixels(z) {
            edge.position.set(-0.5,0,z);
            viewport.render(scene,camera);
            const gl = renderer.getContext();
            const rgba = new Uint8Array(128*128*4);
            gl.readPixels(0,0,128,128,gl.RGBA,gl.UNSIGNED_BYTE,rgba);
            let dark = 0;
            for (let i=0; i<rgba.length; i+=4) if (rgba[i] < 240) dark++;
            return dark;
        }
        const hidden = darkPixels(0), visible = darkPixels(1);
        viewport.dispose(); renderer.dispose();
        for (const object of [model, surface, edge]) object.traverse(child => {
            child.geometry?.dispose(); child.material?.dispose();
        });
        return {parts: model.children.length, outlines: lines(model).length,
            segments: outline.geometry.attributes.position.count/2, bounds: [bounds.min.toArray(),bounds.max.toArray()],
            black: [...outline.geometry.attributes.color.array].every(value => value === 0),
            gray: Math.max(...darkColors), expectedGray: new THREE.Color("#8c8c8c").r,
            context: lines(cube("context")).length, visual: lines(cube("visual")).length,
            smooth: crease(20) === null, sharp: crease(40)?.geometry.attributes.position.count/2,
            nonManifold: crease(90,true) === null, open: open === null, degenerate: degenerate === null, hidden, visible};
    }''')
    check(result["parts"] == 2 and result["outlines"] == 1 and result["segments"] == 12,
          f"Material splits changed the cube's twelve sharp edges: {result}")
    check(result["bounds"] == [[9,19,29],[11,21,31]], f"Component transform lost on sharp edges: {result}")
    check(result["black"] and abs(result["gray"] - result["expectedGray"]) < 1e-6,
          f"Edge colors no longer match native face contrast: {result}")
    check(result["context"] == 0 and result["visual"] == 0, f"Non-solid geometry gained outlines: {result}")
    check(result["smooth"] and result["sharp"] == 1 and result["nonManifold"] and result["open"] and result["degenerate"],
          f"Sharp-edge classification regression: {result}")
    check(result["hidden"] == 0 and result["visible"] >= 32,
          f"Edges must appear on the surface and stay hidden behind it: {result}")
    check(not page.errors and not shader_errors, f"Sharp-edge rendering errors: {page.errors + shader_errors}")
    page.page.context.close()


def test_lighting(browser, base_url):
    """Match native headlight/fill brightness and keep the light aimed along the moving camera."""
    page = CustomizerPage(browser.new_page(viewport={"width":1280,"height":900}), base_url)
    shader_errors = []
    page.page.on("console", lambda message: shader_errors.append(message.text)
                 if message.type == "error" and "WebGLProgram" in message.text else None)
    page.open()
    page.page.evaluate('''async () => {
        const THREE = await import("three");
        const original = THREE.Camera.prototype.updateMatrixWorld;
        THREE.Camera.prototype.updateMatrixWorld = function (...args) {
            const result = original.apply(this, args);
            if (this.isPerspectiveCamera && this.parent?.isScene) {
                const light = this.parent.getObjectByName("Headlight");
                if (light) {
                    const direction = light.getWorldPosition(new THREE.Vector3())
                        .sub(light.target.getWorldPosition(new THREE.Vector3())).normalize();
                    const cameraDirection = new THREE.Vector3().setFromMatrixColumn(this.matrixWorld, 2).normalize();
                    window.lightingState = { dot: direction.dot(cameraDirection),
                        position: this.position.toArray(), direction: cameraDirection.toArray() };
                }
            }
            return result;
        };
    }''')
    page.page.wait_for_function("window.lightingState")
    initial = page.page.evaluate("window.lightingState")
    canvas = page.page.locator("#viewer canvas").bounding_box()
    x, y = canvas["x"] + canvas["width"] / 2, canvas["y"] + canvas["height"] / 2
    for button in ["left", "right"]:
        before = page.page.evaluate("window.lightingState")
        page.page.mouse.move(x, y)
        page.page.mouse.down(button=button)
        page.page.mouse.move(x + 100, y + 60, steps=10)
        page.page.mouse.up(button=button)
        page.page.wait_for_function("before => window.lightingState.position.some((v,i) => Math.abs(v-before[i]) > 0.1)", arg=before["position"])
        state = page.page.evaluate("window.lightingState")
        check(abs(state["dot"] - 1) < 1e-6, f"The headlight lost camera alignment after {button} drag: {state}")
    check(abs(initial["dot"] - 1) < 1e-6, f"The default headlight is offset from the camera: {initial}")

    pixels = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { setupLighting } = await import("./lighting.js");
        const { ViewportRenderer } = await import("./rendering.js");
        const renderer = new THREE.WebGLRenderer({ preserveDrawingBuffer: true });
        const viewport = new ViewportRenderer(renderer);
        viewport.setSize(128,128);
        const scene = new THREE.Scene();
        scene.background = new THREE.Color("black");
        const camera = new THREE.OrthographicCamera(-1.5,1.5,1.5,-1.5,0.1,1000);
        const lighting = setupLighting(scene,camera,renderer);
        const material = new THREE.MeshStandardMaterial({ roughness:0.9, metalness:0 });
        const plane = new THREE.Mesh(new THREE.PlaneGeometry(2,2),material);
        scene.add(plane);
        const samples = [];
        for (const [name, normal] of [["x",[1,0,0]],["y",[0,1,0]],["z",[0,0,1]],["-y",[0,-1,0]]]) {
            const direction = new THREE.Vector3(...normal);
            const rotation = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,0,1),direction);
            plane.quaternion.copy(rotation);
            camera.quaternion.copy(rotation);
            // Include a large pan and changing zoom, without moving the lighting relative to the camera.
            plane.position.set(30,-20,10);
            camera.position.copy(plane.position).addScaledVector(direction,name === "x" ? 50 : 5);
            for (const mode of ["direct","ambient","full"]) {
                lighting.headlight.visible = mode !== "ambient";
                lighting.ambient.visible = mode !== "direct";
                scene.environment = mode === "full" ? lighting.environment.texture : null;
                for (const color of ["white","gray","black"]) {
                    material.color.set(color === "gray" ? new THREE.Color().setRGB(0.5,0.5,0.5,THREE.SRGBColorSpace) : color);
                    camera.updateMatrixWorld();
                    viewport.render(scene,camera);
                    const gl = renderer.getContext(), rgba = new Uint8Array(4);
                    gl.readPixels(64,64,1,1,gl.RGBA,gl.UNSIGNED_BYTE,rgba);
                    samples.push({ normal:name, mode, color, rgb:[...rgba].slice(0,3) });
                }
            }
        }
        plane.geometry.dispose(); material.dispose(); lighting.environment.dispose();
        viewport.dispose(); renderer.dispose();
        return samples;
    }''')
    # SceneKit renders made with Cadova Viewer's headlight=800, ambient=30, gradient environment,
    # and roughness=0.9. Direct/fill match exactly; allow small differences between IBL renderers.
    direct = {"white":233,"gray":119,"black":29}
    ambient = {"white":48,"gray":19,"black":0}
    combined = {"x":[255,137,33],"y":[255,148,36],"z":[255,137,33],"-y":[252,127,30]}
    for sample in pixels:
        mode, color = sample["mode"], sample["color"]
        expected = (direct if mode == "direct" else ambient)[color] if mode != "full" else combined[sample["normal"]][["white","gray","black"].index(color)]
        tolerance = 1 if mode != "full" else 8
        check(all(abs(value-expected) <= tolerance for value in sample["rgb"]),
              f"Lighting no longer matches native brightness ({expected}): {sample}")
    check(not page.errors and not shader_errors, f"Lighting errors: {page.errors + shader_errors}")
    page.page.context.close()


def test_axes(browser, base_url):
    """Origin lines have a stable width and depth; the corner axes follow rotation only."""
    page = CustomizerPage(browser.new_page(viewport={"width": 1280, "height": 900}), base_url)
    shader_errors = []
    page.page.on("console", lambda message: shader_errors.append(message.text)
                 if message.type == "error" and "WebGLProgram" in message.text else None)
    page.open()
    indicator = page.page.locator("#axis-indicator")
    expect(indicator).to_be_visible()
    check(indicator.locator("text").all_text_contents() == ["X", "Y", "Z"], "Missing corner axis labels")
    page.page.evaluate('''async () => {
        const THREE = await import("three");
        const update = THREE.Camera.prototype.updateMatrixWorld;
        THREE.Camera.prototype.updateMatrixWorld = function(...args) {
            update.apply(this, args);
            const origin = this.parent?.getObjectByName("Origin");
            if (origin) window.originState = { visible: origin.visible, position: origin.position.toArray() };
        };
    }''')
    page.page.wait_for_function("window.originState?.visible")
    check(page.page.evaluate("window.originState.position") == [0, 0, 0], "The origin moved to the model center")

    def directions():
        return indicator.locator("line").evaluate_all("lines => lines.map(line => [line.getAttribute('x2'), line.getAttribute('y2')])")

    def settled_directions():
        # Orbit damping advances per frame. Software-rendered CI can need much longer than a
        # fixed delay to settle; wait for consecutive stable frames before testing pan/zoom.
        page.page.evaluate("window.axisStability = { previous: null, frames: 0 }")
        page.page.wait_for_function('''() => {
            const current = [...document.querySelectorAll("#axis-indicator line")]
                .flatMap(line => [Number(line.getAttribute("x2")), Number(line.getAttribute("y2"))]);
            const state = window.axisStability;
            const stable = state.previous && current.every((value, index) =>
                Math.abs(value - state.previous[index]) < 0.0005);
            state.frames = stable ? state.frames + 1 : 0;
            state.previous = current;
            return state.frames >= 5;
        }''', timeout=60000)
        return directions()

    initial = directions()
    canvas = page.page.locator("#viewer canvas").bounding_box()
    x, y = canvas["x"] + canvas["width"] / 2, canvas["y"] + canvas["height"] / 2
    page.page.mouse.move(x, y)
    page.page.mouse.down()
    page.page.mouse.move(x + 120, y + 65, steps=12)
    page.page.mouse.up()
    rotated = settled_directions()
    check(rotated != initial, "Orbiting didn't rotate the corner indicator")
    page.page.mouse.wheel(0, -350)
    page.page.mouse.move(x, y)
    page.page.mouse.down(button="right")
    page.page.mouse.move(x + 40, y + 20, steps=5)
    page.page.mouse.up(button="right")
    moved = settled_directions()
    check(all(abs(float(a) - float(b)) < 0.1 for first, second in zip(rotated, moved)
              for a, b in zip(first, second)), f"Panning or zooming changed the corner directions: {rotated} -> {moved}")
    page.page.set_viewport_size({"width": 390, "height": 844})
    viewer = page.page.locator("#viewer").bounding_box()
    corner = indicator.bounding_box()
    check(abs(corner["x"] - viewer["x"] - 16) < 1 and
          abs(viewer["y"] + viewer["height"] - corner["y"] - corner["height"] - 16) < 1,
          "The indicator isn't anchored at the mobile viewer's bottom-left")
    download = page.page.locator("#download").bounding_box()
    check(corner["x"] + corner["width"] <= download["x"], "The mobile indicator overlaps Download")
    page.page.emulate_media(color_scheme="dark")
    expect(indicator).to_be_visible()

    result = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { OriginAxes, AxisIndicator } = await import("./axes.js");
        const { ViewportRenderer } = await import("./rendering.js");
        const host = document.createElement("div");
        const indicator = new AxisIndicator(host);
        const camera = new THREE.OrthographicCamera(-100, 100, 100, -100, 0.1, 1000);
        function orientation(position, up) {
            camera.position.set(...position);
            camera.up.set(...up);
            camera.lookAt(0, 0, 0);
            camera.updateMatrixWorld();
            indicator.update(camera);
            return [...host.querySelectorAll("line")].map(line =>
                [Number(line.getAttribute("x2")), Number(line.getAttribute("y2"))]);
        }
        const cardinal = [orientation([200, 0, 0], [0, 0, 1]),
            orientation([0, 200, 0], [0, 0, 1]), orientation([0, 0, 200], [0, 1, 0])];
        const renderer = new THREE.WebGLRenderer({ preserveDrawingBuffer: true });
        const viewport = new ViewportRenderer(renderer);
        viewport.setSize(400, 400);
        const scene = new THREE.Scene();
        scene.background = new THREE.Color("#ecebe6");
        const origin = new OriginAxes();
        origin.visible = true;
        scene.add(origin);
        const gl = renderer.getContext();
        function pixel(x, y) {
            const color = new Uint8Array(4);
            gl.readPixels(x, y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, color);
            return [...color];
        }
        function width(ratio, zoom, position, up, sample) {
            orientation(position, up);
            camera.zoom = zoom;
            camera.updateProjectionMatrix();
            renderer.setPixelRatio(ratio);
            viewport.setSize(400, 400);
            viewport.render(scene, camera);
            const point = new THREE.Vector3(...sample).project(camera);
            const size = 400 * ratio;
            const y = Math.floor((point.y + 1) * size / 2);
            const center = Math.floor((point.x + 1) * size / 2);
            const colors = Array.from({length: 13}, (_, index) => pixel(center + index - 6, y));
            // Infer coverage from the rendered pixels in linear light. Native lines are one
            // physical pixel wide, including on a 2x display; two half-covered pixels sum to one.
            const background = scene.background.r, foreground = origin.material.color.r;
            function linear(byte) {
                const value = byte / 255;
                return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
            }
            return colors.reduce((total, color) => total + (background - linear(color[0])) / (background - foreground), 0);
        }
        const widths = [width(1, 1, [0, 0, 200], [0, 1, 0], [0, 20, 0]),
            width(1, 3, [0, 0, 200], [0, 1, 0], [0, 20, 0]),
            width(2, 1, [0, 0, 200], [0, 1, 0], [0, 20, 0]),
            width(1, 1, [0, -200, 0], [0, 0, 1], [0, 0, 20])];
        // A model face above the XY plane must occlude the origin, rather than draw through it.
        orientation([0, 0, 200], [0, 1, 0]);
        const face = new THREE.Mesh(new THREE.PlaneGeometry(20, 20),
            new THREE.MeshBasicMaterial({ color: "#ecebe6", toneMapped: false }));
        face.position.set(0, 30, 10);
        scene.add(face);
        viewport.render(scene, camera);
        const occluded = pixel(200, 260);
        // An off-center perspective view also hides axes underneath a thin floor. A single
        // enormous segment crossing the camera plane used to leak through this surface.
        const perspective = new THREE.PerspectiveCamera(35, 920 / 900, Math.hypot(83.5, 83.5, 25.4) / 100, Math.hypot(83.5, 83.5, 25.4) * 100);
        perspective.up.set(0, 0, 1);
        perspective.position.set(120.15286274431348, -88.92143790718882, 110.70357823965675);
        perspective.lookAt(41.75, 41.75, 12.7);
        perspective.updateMatrixWorld();
        face.geometry.dispose();
        face.geometry = new THREE.PlaneGeometry(83.5, 83.5);
        face.position.set(41.75, 41.75, 5.35);
        viewport.render(scene, perspective);
        const perspectiveOccluded = [30, 40, 50, 60, 70].map(y => {
            const point = new THREE.Vector3(0, y, 0).project(perspective);
            const x = Math.floor((point.x + 1) * 200), row = Math.floor((point.y + 1) * 200);
            return Math.min(...[-1, 0, 1].flatMap(dx =>
                [-1, 0, 1].map(dy => pixel(x + dx, row + dy)[0])));
        });
        face.geometry.dispose();
        face.material.dispose();
        origin.geometry.dispose();
        origin.material.dispose();
        viewport.dispose();
        renderer.dispose();
        return { cardinal, widths, occluded, perspectiveOccluded };
    }''')
    expected = [[[55, 55], [95, 55], [55, 15]], [[15, 55], [55, 55], [55, 15]],
                [[95, 55], [55, 15], [55, 55]]]
    check(all(abs(a - b) < 0.001 for actual, target in zip(result["cardinal"], expected)
              for axis, desired in zip(actual, target) for a, b in zip(axis, desired)),
          f"Incorrect cardinal axis directions: {result['cardinal']}")
    check(all(abs(width - 1) < 0.05 for width in result["widths"]), f"Origin line widths change with zoom, pixel density, or axis: {result}")
    check(result["occluded"][:3] == [236, 235, 230], f"The origin draws through a model face: {result}")
    check(all(pixel == 236 for pixel in result["perspectiveOccluded"]),
          f"The origin leaks through a floor in perspective: {result}")
    check(not shader_errors and not page.errors, f"Axis rendering errors: {shader_errors + page.errors}")
    page.page.context.close()


def faulty_worker(page, code):
    """Injects a fault into the first real worker. A restart gets the original worker script."""
    requests = []

    def serve(route):
        requests.append(route.request.url)
        response = route.fetch()
        script = response.text()
        if len(requests) == 1:
            script = script.replace("    try {", f"    try {{\n{code}", 1)
        route.fulfill(response=response, body=script)

    page.context.route("**/worker.js", serve)
    return requests


def expect_recovery(page, message):
    expect(page.page.locator("#status")).to_contain_text(message, timeout=TIMEOUT)
    expect(page.page.locator("#cancel")).to_be_hidden()
    expect(page.page.locator("#building")).to_be_hidden()
    expect(page.page.locator("#retry")).to_be_visible()
    expect(page.page.locator("#download")).to_be_disabled()


def test_worker_recovery(browser, base_url):
    """Real worker hangs/crashes can be stopped and retried; traps never fall back to the page."""
    faults = {
        "cancel": 'while (true) {}',
        "exception": 'throw new Error("Injected build failure");',
        "crash": 'setTimeout(() => { throw new Error("Injected worker crash"); }, 0); return;',
        "stack": '''self.postMessage({type: "built", id: data.id, exitCode: -1, data: null,
            stackOverflow: true, log: ["Crashed: stack limit"], milliseconds: 0}); return;''',
        "trap": '''self.postMessage({type: "built", id: data.id, exitCode: -1, data: null,
            log: ["Crashed: unreachable", "A continuation keeps its first word"], milliseconds: 0}); return;''',
        "preview": '''self.postMessage({type: "built", id: data.id, exitCode: 0,
            data: new Uint8Array([1, 2, 3]), fileName: "broken.3mf", log: [], milliseconds: 0}); return;''',
    }
    for name, fault in faults.items():
        page = CustomizerPage(browser.new_page(), base_url)
        workers = faulty_worker(page.page, f'if (data.type === "build" && data.parameters.Width === 65) {{ {fault} }}')
        downloads = []
        page.page.on("request", lambda request: downloads.append(request.url) if "model.wasm" in request.url else None)
        # Track the actual worker so a delayed message from a terminated generation can be replayed.
        page.page.add_init_script('''
            const NativeWorker = Worker;
            window.workers = [];
            window.Worker = class extends NativeWorker {
                constructor(...args) { super(...args); window.workers.push(this); }
                postMessage(data, ...args) { this.lastRequest = data; super.postMessage(data, ...args); }
            };
        ''')
        page.open()
        page.set_number("Width", "65")
        if name == "cancel":
            expect(page.page.locator("#cancel")).to_be_visible()
            page.page.wait_for_function('window.workers[0].lastRequest.parameters?.Width === 65')
            # A worker stuck in a synchronous loop must leave the page and controls responsive.
            check(page.page.evaluate('() => new Promise(resolve => setTimeout(() => resolve(true), 20))'), "The page froze")
            page.page.evaluate('window.oldReply = window.workers[0].onmessage; window.oldID = window.workers[0].lastRequest.id')
            page.set_number("Width", "75")  # queued values survive cancellation
            page.page.locator("#cancel").click()
            expect_recovery(page, "Build cancelled")
        elif name == "exception":
            expect_recovery(page, "Injected build failure")
        elif name == "crash":
            expect_recovery(page, "worker stopped unexpectedly")
        elif name == "stack":
            expect_recovery(page, "worker stack limit")
        elif name == "trap":
            expect_recovery(page, "failed to build")
            expect(page.page.locator("#log")).to_contain_text("A continuation keeps its first word")
        else:
            expect(page.page.locator("#retry")).to_be_visible(timeout=TIMEOUT)
            expect(page.page.locator("#download")).to_be_disabled()
        expect(page.page.locator("#overlay")).to_be_hidden()  # last successful preview is retained
        page.rebuild(lambda: page.page.locator("#retry").click())
        mesh = page.download()
        width = 75 if name == "cancel" else 65
        check(abs(mesh.extent(0) - width) < 0.01, f"{name}: retry lost the chosen width")
        check(len(workers) == 2, f"{name}: retry didn't start a fresh worker: {workers}")
        check(len(downloads) == 1, f"{name}: retry downloaded the WASM again: {downloads}")
        if name == "cancel":
            page.page.evaluate('''window.oldReply({data: {type: "built", id: window.oldID,
                exitCode: -1, data: null, log: ["obsolete failure"]}})''')
            expect(page.page.locator("#status")).to_be_hidden()
            expect(page.page.locator("#download")).to_be_enabled()
        check(not page.errors, f"{name}: recovery had page errors: {page.errors}")
        page.page.context.close()


def test_loading_recovery(browser, base_url):
    """Network and worker startup failures offer a retry before the form exists."""
    bundled_file = next(path for path in json.loads((CUSTOMIZER / "resources.json").read_text()) if path.endswith("plate-depth.txt"))
    for resource in ["model.wasm", "resources.json", f"resources/{bundled_file}", "worker.js"]:
        page = CustomizerPage(browser.new_page(), base_url)
        requests = []

        def fail_first(route):
            requests.append(route.request.url)
            if len(requests) == 1:
                route.fulfill(status=503, body="Temporary failure")
            else:
                route.continue_()

        page.page.context.route(f"**/{resource}", fail_first)
        page.page.goto(f"{base_url}/index.html#Width=75")
        expect_recovery(page, "worker stopped unexpectedly" if resource == "worker.js" else "Couldn't load")
        expect(page.page.locator("#reset")).to_be_disabled()
        page.rebuild(lambda: page.page.locator("#retry").click())
        expect(page.number_field("Width")).to_have_value("75")
        check(abs(page.download().extent(0) - 75) < 0.01, f"Retry after loading {resource} lost URL settings")
        check(not page.errors, f"Loading recovery had page errors: {page.errors}")
        page.page.context.close()

    page = CustomizerPage(browser.new_page(), base_url)
    workers = faulty_worker(page.page, 'if (data.type === "load") { while (true) {} }')
    page.page.goto(f"{base_url}/index.html#Width=75")
    expect(page.page.locator("#cancel")).to_be_visible()
    page.page.locator("#cancel").click()
    expect_recovery(page, "Loading cancelled")
    page.rebuild(lambda: page.page.locator("#retry").click())
    check(len(workers) == 2, "Cancelling loading didn't restart the worker")
    check(abs(page.download().extent(0) - 75) < 0.01, "Cancelling loading lost URL settings")
    check(not page.errors, f"Cancelling loading had page errors: {page.errors}")
    page.page.context.close()


def test_worker_timeouts(browser, base_url):
    """The watchdog stops real hangs during both loading and building."""
    for operation in ["load", "build"]:
        page = CustomizerPage(browser.new_page(), base_url)
        # Speed up only the watchdog, after it has been armed, without changing production limits.
        page.page.add_init_script('''
            const nativeTimeout = setTimeout;
            window.setTimeout = (callback, delay, ...args) => nativeTimeout(callback,
                delay === 120000 ? (window.shortenWatchdog ? 2000 : 10000) : delay, ...args);
        ''')
        faulty_worker(page.page, f'if (data.type === "{operation}") {{ while (true) {{}} }}')
        if operation == "load":
            page.page.add_init_script('window.shortenWatchdog = true')
            page.page.goto(f"{base_url}/index.html")
            expect_recovery(page, "Loading the model took longer")
        else:
            # The first build hangs too, so wait for loading and the automatic build watchdog.
            page.page.goto(f"{base_url}/index.html")
            expect_recovery(page, "Build stopped after 2 minutes")
        page.page.evaluate('window.shortenWatchdog = false')
        page.rebuild(lambda: page.page.locator("#retry").click())
        check(abs(page.download().extent(0) - 40) < 0.01, "Retry after a timeout didn't build the model")
        check(not page.errors, f"Timeout recovery had page errors: {page.errors}")
        page.page.context.close()


# Chromium renders WebGL in software where there's no GPU, such as on CI machines
CHROMIUM_ARGUMENTS = ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]


def main(engines):
    check(CUSTOMIZER.joinpath("model.wasm").exists(), f"No customizer in {CUSTOMIZER}; generate it first")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=CUSTOMIZER))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f"http://127.0.0.1:{server.server_address[1]}"

    failed = False
    with sync_playwright() as playwright:
        runs = [(engine, run, []) for engine in engines for run in (
            test, test_tabs, test_single_model, test_grid, test_grid_theme, test_viewer_defaults, test_grid_navigation, test_line_rendering, test_sharp_edges, test_lighting, test_axes, test_worker_recovery, test_loading_recovery, test_worker_timeouts,
        )]
        if "chromium" in engines:
            runs.append(("chromium", test_without_webgl, ["--disable-webgl", "--disable-3d-apis"]))
        for engine, run, arguments in runs:
            name = f"{engine} ({run.__name__})"
            launcher = getattr(playwright, engine)
            browser = launcher.launch(args=(CHROMIUM_ARGUMENTS if engine == "chromium" else []) + arguments)
            try:
                run(browser, base_url)
                print(f"{name}: passed")
            except (AssertionError, PlaywrightError) as error:
                print(f"{name}: FAILED: {error}")
                failed = True
            finally:
                browser.close()
    server.shutdown()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1:] or ["chromium"])
