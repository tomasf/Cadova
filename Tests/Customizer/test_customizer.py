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
import time
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
        # A finished build notes its time; a failure shows an error over the model view
        self.page.wait_for_function("""() =>
            document.getElementById("build-time").textContent.startsWith("Built in")
                || document.getElementById("status").textContent !== ""
        """, timeout=TIMEOUT)
        error = self.page.locator("#status").text_content()
        if error:
            log = self.page.locator("#log").inner_text()
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


class CDNCache:
    """Serves the page's files from the CDN, three.js and the WASI library, to every test from one
    download each. Each test starts a new browser with an empty cache, and the CDN now and then stalls
    a download for 10 to 15 seconds, which was enough to time out whichever test it landed in."""

    def __init__(self):
        self.files = {}

    def route(self, route):
        url = route.request.url
        if url not in self.files:
            # A stalled download is retried, rather than left to hold up the test that asked for it
            for attempt in range(3):
                try:
                    response = route.fetch(timeout=10_000)
                    break
                except PlaywrightError as error:
                    if "closed" in str(error):
                        return  # the test is already done with the page
            else:
                try:
                    route.abort()
                except PlaywrightError:
                    pass
                return
            if response.status != 200:
                route.fulfill(response=response)
                return
            # Only what the browser needs: the body is already decoded, so the CDN's encoding no longer applies
            headers = {name: value for name, value in response.headers.items()
                       if name.lower() in ("content-type", "access-control-allow-origin")}
            self.files[url] = (headers, response.body())
        headers, body = self.files[url]
        try:
            route.fulfill(status=200, headers=headers, body=body)
        except PlaywrightError:
            pass  # the page closed while it waited

    def browser(self, browser):
        """Routes the CDN through the cache in every page the browser opens."""
        new_page = browser.new_page

        def routed_page(**options):
            page = new_page(**options)
            page.context.route("https://cdn.jsdelivr.net/**", self.route)
            return page
        browser.new_page = routed_page
        return browser


class TestServer(http.server.ThreadingHTTPServer):
    # The browser asks for a page's modules all at once. With the default queue of 5 connections
    # waiting to be accepted, the rest were reset, and a module that failed to load left the page
    # stuck on loading until the test timed out.
    request_queue_size = 128


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
    console = []
    page.page.on("console", lambda message: console.append(message.text))

    # The form comes from the model's own parameter list
    page.open()
    expect(page.page.locator("#overlay")).to_be_hidden()  # the preview shows the model
    expect(page.page.locator("#title")).to_have_text("Test Parts")
    expect(page.page.locator("#subtitle")).to_have_text("Parts for testing the web customizer.")
    expect(page.page.get_by_role("tab", name="Test Plate", exact=True)).to_have_attribute("aria-selected", "true")
    expect(page.page.locator(".model-description")).to_have_text("A plate with holes.")
    for name in ["Width", "Holes"]:
        expect(page.number_field(name)).to_be_attached()
    # A build that goes well shows nothing more, and its time and the model's own prints go to the console
    expect(page.page.locator("#alert")).to_be_hidden()
    check(any(text.startswith("Built in") for text in console), f"The build time didn't reach the console: {console}")
    check("Building a plate 40 mm wide" in console, f"The model's print didn't reach the console: {console}")
    # A number shows its unit after the field, and one without a unit shows none
    units = page.page.evaluate("""() => Object.fromEntries([...document.querySelectorAll(".field")].map(field =>
        [field.querySelector("label").textContent, field.querySelector(".unit")?.textContent ?? null]))""")
    check(units.get("Width") == "mm" and units.get("Holes") == "pcs" and units.get("Thick") is None,
          f"Units after the number fields are wrong: {units}")
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

    # Changing a value in the form rebuilds the model, and values never go in the address
    page.rebuild(lambda: page.set_number("Width", "80"))
    changed = page.download()
    check(abs(changed.extent(0) - 80) < 0.01, f"Width from the form is {changed.extent(0)}, expected 80")
    check(abs(changed.extent(2) - 6) < 0.01, f"Thickness after changing the width is {changed.extent(2)}, expected 6")
    expect(page.page).to_have_url(re.compile(r"/index\.html$"))

    page.rebuild(lambda: page.page.get_by_role("button", name="Square").click())
    square = page.download()
    check(square.triangles < changed.triangles,
          f"Square corners should need fewer triangles than rounded ones ({square.triangles} vs {changed.triangles})")
    check(abs(square.extent(0) - 80) < 0.01, "Changing the corners lost the width")

    page.rebuild(lambda: page.set_number("Holes", "0"))
    no_holes = page.download()
    check(no_holes.triangles < square.triangles,
          f"Removing the holes should remove triangles ({no_holes.triangles} vs {square.triangles})")

    # Dragging a slider makes many changes in a row, which end in one build with the last value
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
    dragged = page.download()
    check(abs(dragged.extent(0) - 55) < 0.01, f"Width after dragging is {dragged.extent(0)}, expected 55")

    # An older link with values in its address opens with the defaults, and loses the values
    page.open("#Width=80&Thick=true")
    expect(page.number_field("Width")).to_have_value("40")
    expect(page.page).to_have_url(re.compile(r"/index\.html$"))

    check(not page.errors, f"The page had errors: {page.errors}")


def test_tabs(browser, base_url):
    """Each model with parameters gets a tab, and each keeps its own values, even for parameters with
    the same label."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open()
    page.rebuild(lambda: page.set_number("Width", "80"))
    plate = page.download()
    check(abs(plate.extent(0) - 80) < 0.01, f"Plate width is {plate.extent(0)}, expected 80")

    # Tabs don't show groups, so only a tab whose title clashes with another names its group
    tabs = page.page.get_by_role("tab").all_text_contents()
    check(tabs == ["Test Plate", "Spacer", "Washer", "Extras › Spacer"], f"The tabs are named {tabs}")

    # The spacer's Width is its own parameter, so it keeps its default
    page.rebuild(lambda: page.page.get_by_role("tab", name="Spacer", exact=True).click())
    expect(page.page.get_by_role("tab", name="Spacer", exact=True)).to_have_attribute("aria-selected", "true")
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
    page.rebuild(lambda: page.page.get_by_role("tab", name="Test Plate", exact=True).click())
    expect(page.number_field("Width")).to_have_value("80")
    expect(page.page).to_have_url(re.compile(r"/index\.html$"))
    plate = page.download()
    check(abs(plate.extent(0) - 80) < 0.01, f"Plate width after changing the spacer's is {plate.extent(0)}, expected 80")

    # A link opens the same tab, with the default values
    page.open("#model=spacer")
    expect(page.page.get_by_role("tab", name="Spacer", exact=True)).to_have_attribute("aria-selected", "true")
    spacer = page.download()
    check(abs(spacer.extent(0) - 20) < 0.01, f"Spacer diameter from a link is {spacer.extent(0)}, expected 20")
    check(not page.errors, f"The page had errors: {page.errors}")


def test_dynamic_parameters(browser, base_url):
    """The form follows the parameters each build uses, keeping the values of the ones it hides."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open()
    expect(page.page.locator("#reset")).to_be_hidden()  # nothing to reset yet
    radius = page.number_field("Corner radius")
    expect(radius).to_have_value("3")
    page.rebuild(lambda: page.set_number("Corner radius", "5"))

    # Square corners have no radius, so the field goes, and the fields around it stay
    page.number_field("Width").evaluate("field => field.dataset.marked = 'yes'")
    page.rebuild(lambda: page.page.get_by_role("button", name="Square").click())
    expect(page.page.locator(".field label", has_text="Corner radius")).to_have_count(0)
    check(page.number_field("Width").get_attribute("data-marked") == "yes", "The form was rebuilt instead of updated")

    # Rounding them again brings it back, with the value it had, in the same place
    page.rebuild(lambda: page.page.get_by_role("button", name="Rounded").click())
    expect(radius).to_have_value("5")
    labels = page.page.locator(".field label").all_text_contents()
    check(labels.index("Corner radius") == labels.index("Corners") + 1, f"The corner radius came back out of place: {labels}")
    rounded = page.download()
    check(abs(rounded.extent(0) - 40) < 0.01, f"Width with a corner radius of 5 is {rounded.extent(0)}, expected 40")

    # Reset brings back the defaults, including for the hidden value, and goes away until
    # something changes again
    page.rebuild(lambda: page.page.get_by_role("button", name="Square").click())
    expect(page.page.locator("#reset")).to_be_visible()
    page.rebuild(lambda: page.page.locator("#reset").click())
    expect(radius).to_have_value("3")
    expect(page.page.locator("#reset")).to_be_hidden()
    check(not page.errors, f"The page had errors: {page.errors}")
    page.page.context.close()


def test_model_menu(browser, base_url):
    """With more models than fit as tabs, the page offers a menu, with a section for each group."""
    page = CustomizerPage(browser.new_page(), base_url)
    # The fixture has only three models, so the limit is lowered to show the menu
    page.page.add_init_script("window.cadovaTabLimit = 2")
    page.open()
    menu = page.page.locator("#model-menu")
    expect(menu).to_be_visible()
    expect(page.page.get_by_role("tab")).to_have_count(0)
    entries = menu.evaluate("""menu => [...menu.children].map(child => child.tagName === "OPTGROUP"
        ? {group: child.label, models: [...child.children].map(option => option.textContent)}
        : child.textContent)""")
    check(entries == ["Test Plate", "Spacer", {"group": "Extras", "models": ["Washer", "Spacer"]}],
          f"The menu lists the models in the wrong order or sections: {entries}")
    expect(menu).to_have_value("plate")

    # Choosing a model builds it, and the address names it, as with a tab
    page.rebuild(lambda: menu.select_option("extras/washer"))
    expect(page.number_field("Diameter")).to_have_value("12")
    expect(page.page).to_have_url(re.compile(r"#model=extras/washer$"))
    washer = page.download()
    check(abs(washer.extent(0) - 12) < 0.01, f"Washer diameter is {washer.extent(0)}, expected 12")

    # A link opens the menu on its model
    page.open("#model=spacer")
    expect(menu).to_have_value("spacer")
    check(not page.errors, f"The page had errors: {page.errors}")
    page.page.context.close()


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
        // The rim sample is where the fade is partway, so it's fainter than inside but still there
        const result = { inner: sample(0, 50), rim: sample(0, 100),
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
    """Keep the faint grid and antialiased origin as they're meant to look: a little dimmer than
    SceneKit renders Cadova Viewer's, which are 47 and 74 at their brightest."""
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
            // x = 20 is a grid line; y = 25 avoids a crossing. Half a pixel of white at 3.6%
            // alpha over 5% sRGB gray gives about 41/255 after linear-light blending.
            const gridProfile = [238, 239, 240, 241].map(x => pixel(x, 250));
            grid.visible = false;
            const origin = new OriginAxes();
            origin.visible = true;
            scene.add(origin);
            viewport.render(scene, camera);
            // The centered #575757 origin line comes out as [13, 63, 63, 13].
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
              and all(37 <= value <= 45 for value in pixels["gridProfile"][1:3]),
              f"The {mode} grid's contrast has changed: {pixels}")
        check(all(abs(actual - expected) <= 3 for actual, expected in zip(pixels["originProfile"], [13, 63, 63, 13])),
              f"The {mode} origin's antialiasing has changed: {pixels}")
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
            // A part looks as its materials say, whatever its semantic, as in Cadova Viewer
            opaqueContext: cube("context").children.every(mesh => mesh.material.opacity === 1 && !mesh.material.transparent),
            smooth: crease(20) === null, sharp: crease(40)?.geometry.attributes.position.count/2,
            nonManifold: crease(90,true) === null, open: open === null, degenerate: degenerate === null, hidden, visible};
    }''')
    check(result["parts"] == 2 and result["outlines"] == 1 and result["segments"] == 12,
          f"Material splits changed the cube's twelve sharp edges: {result}")
    check(result["bounds"] == [[9,19,29],[11,21,31]], f"Component transform lost on sharp edges: {result}")
    check(result["black"] and abs(result["gray"] - result["expectedGray"]) < 1e-6,
          f"Edge colors no longer match native face contrast: {result}")
    check(result["context"] == 0 and result["visual"] == 0, f"Non-solid geometry gained outlines: {result}")
    check(result["opaqueContext"], f"An opaque context part was drawn see-through: {result}")
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


def test_navigation(browser, base_url):
    """Native turntable/pivots/inertia, plus browser mouse, trackpad and touch gesture routing."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.open()
    result = page.page.evaluate('''async () => {
        const THREE = await import("three");
        const { ViewportControls } = await import("./navigation.js");
        const canvas = document.createElement("canvas");
        canvas.style.cssText = "position:fixed;left:10px;top:10px;width:400px;height:300px";
        document.body.append(canvas);
        const camera = new THREE.PerspectiveCamera(30,4/3,0.01,10000);
        camera.up.set(0,0,1);
        camera.position.set(0,-100,40); camera.lookAt(0,0,0); camera.updateMatrixWorld();
        const position = camera.position.clone(), quaternion = camera.quaternion.clone();
        const mesh = new THREE.Mesh(new THREE.BoxGeometry(20,20,20),new THREE.MeshBasicMaterial());
        const object = new THREE.Group(); object.add(mesh);
        const box = new THREE.Box3().setFromObject(object);
        const controls = new ViewportControls(camera,canvas);
        controls.setModel(object,box);
        const center = new THREE.Vector2(210,160), offCenter = new THREE.Vector2(280,180);
        const pixel = point => {
            camera.updateMatrixWorld();
            const p = point.clone().project(camera);
            return new THREE.Vector2(210+p.x*200,160-p.y*150);
        };
        function reset() { controls.reset(); camera.position.copy(position); camera.quaternion.copy(quaternion); camera.updateMatrixWorld(); }
        const state = controls.begin(center), pivot = state.pivot.clone();
        controls.apply(state,new THREE.Vector4(100,0,0,0),"orbit");
        const orbitPosition = camera.position.toArray(), orbitAnchor = pixel(pivot).distanceTo(center);
        const once = camera.position.clone();
        controls.apply(state,new THREE.Vector4(100,0,0,0),"orbit");
        const drift = camera.position.distanceTo(once);
        controls.apply(state,new THREE.Vector4(0,120,0,0),"orbit");
        const overPole = new THREE.Vector3(0,1,0).applyQuaternion(camera.quaternion).z < 0;
        reset();
        const panState = controls.begin(center);
        controls.apply(panState,new THREE.Vector4(30,-20,0,0),"pan");
        const panPixel = pixel(panState.pivot).sub(center).toArray();
        const panOrientation = Math.abs(camera.quaternion.dot(quaternion));
        reset();
        const zoomPivot = controls.pivot(offCenter), distance = camera.position.distanceTo(zoomPivot);
        controls.zoom(0.5,offCenter);
        const zoomRatio = camera.position.distanceTo(zoomPivot)/distance, zoomAnchor = pixel(zoomPivot).distanceTo(offCenter);
        controls.zoom(40,offCenter);
        const minimum = camera.position.distanceTo(zoomPivot)/controls.sphere.radius;
        controls.zoom(-40,offCenter);
        const maximum = camera.position.distanceTo(zoomPivot)/controls.sphere.radius;
        reset();
        camera.quaternion.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,-1).applyQuaternion(quaternion),0.7));
        const rolled = camera.quaternion.clone(), rollState = controls.begin(center);
        controls.apply(rollState,new THREE.Vector4(0,0,0,0),"orbit");
        const keepsRoll = Math.abs(camera.quaternion.dot(rolled));
        reset();
        const glideState = controls.begin(center);
        function glide(fps) {
            controls.startInertia(glideState,new THREE.Vector4(40,0,0,0),new THREE.Vector4(120,0,0,0),"orbit");
            controls.update(0);
            for (let i=1;i<=fps;i++) controls.update(i*1000/fps);
            const speed = controls.inertia.velocity.x;
            for (let i=fps+1;i<=fps*4;i++) controls.update(i*1000/fps);
            return {speed,stopped:controls.inertia === null};
        }
        const sixty = glide(60), oneTwenty = glide(120);
        controls.startInertia(glideState,new THREE.Vector4(0,0,0,0),new THREE.Vector4(5,0,0,0),"orbit");
        const noSlowGlide = controls.inertia === null;

        // DOM PointerEvents let both engines exercise multi-contact input. Only capture is stubbed:
        // constructed events don't register hardware pointer IDs with the browser.
        canvas.setPointerCapture = () => {};
        canvas.hasPointerCapture = () => false;
        const pointer = (type,id,x,y,extra={}) => canvas.dispatchEvent(new PointerEvent(type,{
            bubbles:true,cancelable:true,pointerId:id,pointerType:"mouse",button:0,buttons:type === "pointerup" ? 0 : 1,
            clientX:x,clientY:y,...extra}));
        const wheel = extra => {
            const event = new WheelEvent("wheel",{bubbles:true,cancelable:true,clientX:280,clientY:180,...extra});
            // Real wheel events carry the legacy wheelDelta browsers report: 120 per detent for a
            // wheel, and -3 times the delta for a trackpad. A constructed event's doesn't.
            if (extra.legacyDelta !== undefined) Object.defineProperty(event,"wheelDeltaY",{value:extra.legacyDelta});
            if (extra.legacyDeltaX !== undefined) Object.defineProperty(event,"wheelDeltaX",{value:extra.legacyDeltaX});
            canvas.dispatchEvent(event); return event.defaultPrevented;
        };
        const touch = {pointerType:"touch"};
        reset();
        pointer("pointerdown",1,210,160,{shiftKey:true}); pointer("pointermove",1,240,170);
        const axisLock = controls.drag.axis === "x" && controls.drag.delta.y === 0;
        controls.pivotVisual.shownAt -= 100;
        controls.updatePivot();
        const marker = Number(controls.marker.style.opacity) === 1 && controls.marker.querySelector("circle").getAttribute("r") === "4"
            && Math.abs(parseFloat(controls.marker.style.left)-210) < 1e-6 && Math.abs(parseFloat(controls.marker.style.top)-160) < 1e-6;
        pointer("pointerup",1,240,170);
        controls.pivotVisual.hiddenAt -= 700; controls.updatePivot();
        const markerHidden = controls.pivotVisual === null && controls.marker.style.opacity === "0";
        const quickGlide = controls.inertia !== null;
        const releasePosition = camera.position.clone(); controls.update(0); controls.update(1000/60);
        const coastMoved = camera.position.distanceTo(releasePosition) > 0.1;
        pointer("pointerdown",1,210,160);
        const grabStopsGlide = controls.inertia === null;
        pointer("pointerup",1,210,160);
        reset();
        pointer("pointerdown",1,210,160,{altKey:true}); pointer("pointermove",1,230,175);
        const altPan = controls.drag.motion === "pan" && Math.abs(camera.quaternion.dot(quaternion)) > 1-1e-10;
        await new Promise(resolve => setTimeout(resolve,80));
        pointer("pointerup",1,230,175);
        const pausedRelease = controls.inertia === null;
        // A finger that stops before it lifts often sends no more moves. The pause still stops it.
        reset();
        const frame = () => new Promise(resolve => setTimeout(resolve,16));
        pointer("pointerdown",1,210,160,touch);
        for (let x=230;x<=290;x+=20) { await frame(); pointer("pointermove",1,x,160,touch); }
        await new Promise(resolve => setTimeout(resolve,40));
        pointer("pointerup",1,290,160,touch);
        const stoppedRelease = controls.inertia === null;
        reset();
        pointer("pointerdown",1,210,160,touch);
        for (let x=230;x<=290;x+=20) { await frame(); pointer("pointermove",1,x,160,touch); }
        pointer("pointerup",1,290,160,touch);
        const flingRelease = controls.inertia !== null;
        reset();
        pointer("pointerdown",1,210,160); pointer("pointermove",1,230,175);
        pointer("pointercancel",1,230,175);
        const cancelStops = controls.pointers.size === 0 && controls.inertia === null;
        reset();
        let before = camera.position.distanceTo(controls.pivot(offCenter));
        const wheelPrevented = wheel({deltaY:-3,deltaMode:1});
        const mouseZoom = camera.position.distanceTo(controls.zoomPivot.world)/before;
        reset(); before = camera.position.distanceTo(controls.pivot(offCenter));
        wheel({deltaY:-100,legacyDelta:120,legacyDeltaX:0});
        const pixelMouseZoom = camera.position.distanceTo(controls.zoomPivot.world)/before;
        reset(); before = camera.position.distanceTo(controls.pivot(offCenter));
        // An accelerated wheel's pixel delta is any size, which once made it pan like a trackpad
        wheel({deltaY:-13.5,legacyDelta:120,legacyDeltaX:0});
        // Without a zoom, there's no zoom pivot, and the ratio reads as "didn't zoom"
        const nativeMouseZoom = controls.zoomPivot ? camera.position.distanceTo(controls.zoomPivot.world)/before : null;
        reset(); const beforePan = pixel(controls.sphere.center);
        wheel({deltaX:9,deltaY:-6,legacyDelta:18,legacyDeltaX:-27});
        const trackpadPan = pixel(controls.sphere.center).sub(beforePan).toArray();
        reset(); before = camera.position.distanceTo(controls.pivot(offCenter));
        wheel({deltaY:-10,shiftKey:true,legacyDelta:30,legacyDeltaX:0}); wheel({deltaY:-10,legacyDelta:30,legacyDeltaX:0});
        const modifierMomentum = camera.position.distanceTo(controls.zoomPivot.world)/before;
        reset(); before = camera.position.distanceTo(controls.pivot(offCenter));
        wheel({deltaY:-10,ctrlKey:true});
        const pinchZoom = camera.position.distanceTo(controls.pinch.state.pivot)/before;
        const pinchAnchor = pixel(controls.pinch.state.pivot).distanceTo(offCenter);
        controls.finishPinch(false);

        function two() { reset(); pointer("pointerdown",11,190,160,touch); pointer("pointerdown",12,230,160,touch); }
        two();
        const touchPivot = controls.drag.state.pivot.clone();
        pointer("pointermove",11,200,175,touch); pointer("pointermove",12,240,175,touch);
        const touchPan = pixel(touchPivot).sub(center).toArray();
        two(); const touchDistance = camera.position.distanceTo(controls.drag.state.pivot);
        pointer("pointermove",11,170,160,touch); pointer("pointermove",12,250,160,touch);
        const touchPinch = camera.position.distanceTo(controls.drag.state.pivot)/touchDistance;
        const touchAnchor = pixel(controls.drag.state.pivot).distanceTo(center);
        pointer("pointerup",11,170,160,touch); pointer("pointerup",12,250,160,touch);
        const pinchRelease = controls.inertia?.motion === "touch" && controls.inertia.velocity.z !== 0;
        const coastPivot = controls.inertia.state.pivot.clone();
        controls.update(0); controls.update(1000/60);
        const pinchCoastAnchor = pixel(coastPivot).distanceTo(center);
        // Fingers rarely lift at once. The one left over from a pinch doesn't orbit, or fling, the view.
        two(); const staggerQuaternion = camera.quaternion.clone();
        pointer("pointermove",11,180,160,touch); pointer("pointermove",12,240,160,touch);
        pointer("pointerup",11,180,160,touch);
        pointer("pointermove",12,260,175,touch); pointer("pointermove",12,280,190,touch);
        pointer("pointerup",12,280,190,touch);
        for (let i=0;i<=30;i++) controls.update(i*1000/60);
        const staggeredLift = Math.abs(camera.quaternion.dot(staggerQuaternion)) > 1-1e-10;
        two(); const twistDistance = camera.position.distanceTo(controls.drag.state.pivot);
        for (let i=1;i<=9;i++) {
            const a=i*Math.PI/18;
            pointer("pointermove",11,210-20*Math.cos(a),160-20*Math.sin(a),touch);
            pointer("pointermove",12,210+20*Math.cos(a),160+20*Math.sin(a),touch);
        }
        // Twisting doesn't roll the view. WebKit rounds the contacts to whole pixels, which can read as
        // a slight pinch, so only the camera's orientation is checked.
        const twistIgnored = Math.abs(camera.quaternion.dot(quaternion)) > 1-1e-10;
        const twistDistanceRatio = camera.position.distanceTo(controls.drag.state.pivot)/twistDistance;
        reset();
        const gesture = (type,scale,rotation,documentTarget=false) => {
            const event = new Event(type,{bubbles:true,cancelable:true});
            Object.assign(event,{scale,rotation}); (documentTarget ? document : canvas).dispatchEvent(event);
        };
        pointer("pointermove",1,210,160);
        const safariStart = camera.position.clone(), safariQuaternion = camera.quaternion.clone();
        gesture("gesturestart",1,0); gesture("gesturechange",1.01,15);
        const safariTwistIgnored = !controls.gesture.zooming && camera.position.distanceTo(safariStart) === 0
            && Math.abs(camera.quaternion.dot(safariQuaternion)) > 1-1e-10;
        const safariPose = camera.position.clone(); wheel({deltaY:-10,ctrlKey:true});
        const noDuplicatePinch = camera.position.distanceTo(safariPose) === 0;
        gesture("gestureend",1.01,15);
        const safariNoCoast = controls.inertia === null;
        reset(); gesture("gesturestart",1,0,true);
        before = camera.position.distanceTo(controls.gesture.state.pivot);
        gesture("gesturechange",2,1,true);
        const safariPinch = camera.position.distanceTo(controls.gesture.state.pivot)/before;
        gesture("gestureend",2,1,true);
        // Zooming by button eases in over 200 ms, and a second press adds on to what's left
        reset(); before = camera.position.distanceTo(controls.pivot(center));
        controls.animateZoom(Math.log(2),center); controls.update(1000); controls.update(1100);
        controls.animateZoom(Math.log(2),center); controls.update(2000); controls.update(2300);
        const buttonZoom = camera.position.distanceTo(controls.pivot(center))/before;
        controls.dispose();
        const event = new WheelEvent("wheel",{bubbles:true,cancelable:true,deltaY:10});
        canvas.dispatchEvent(event);
        const disposed = !event.defaultPrevented && controls.inertia === null;
        canvas.remove(); mesh.geometry.dispose(); mesh.material.dispose();
        return {pivot:pivot.toArray(),orbitPosition,orbitAnchor,drift,overPole,panPixel,panOrientation,zoomRatio,zoomAnchor,
            minimum,maximum,keepsRoll,sixty,oneTwenty,noSlowGlide,axisLock,marker,markerHidden,quickGlide,coastMoved,grabStopsGlide,
            altPan,pausedRelease,stoppedRelease,flingRelease,cancelStops,wheelPrevented,mouseZoom,pixelMouseZoom,nativeMouseZoom,trackpadPan,modifierMomentum,
            pinchZoom,pinchAnchor,touchPan,touchPinch,touchAnchor,pinchRelease,pinchCoastAnchor,staggeredLift,twistIgnored,twistDistanceRatio,
            safariTwistIgnored,noDuplicatePinch,safariNoCoast,safariPinch,buttonZoom,disposed};
    }''')
    def close(actual, expected, tolerance=1e-6):
        return all(abs(a-b) < tolerance for a,b in zip(actual,expected))
    check(close(result["pivot"],[0,-10,4]) and close(result["orbitPosition"],[-90,-10,40]),
          f"Orbit differs from native picking/sensitivity: {result}")
    check(result["orbitAnchor"] < 1e-6 and result["drift"] < 1e-6 and result["overPole"] and abs(result["keepsRoll"]-1) < 1e-6,
          f"Orbit drifts, loses roll, or clamps at a pole: {result}")
    check(close(result["panPixel"],[30,-20]) and abs(result["panOrientation"]-1) < 1e-6,
          f"Panning doesn't track the grabbed point: {result}")
    check(abs(result["zoomRatio"]-0.6065306597) < 1e-6 and result["zoomAnchor"] < 1e-6
          and abs(result["minimum"]-0.05) < 1e-6 and abs(result["maximum"]-40) < 1e-6,
          f"Cursor zoom/limits differ from native: {result}")
    check(abs(result["sixty"]["speed"]-120*0.95**60) < 1e-6
          and abs(result["sixty"]["speed"]-result["oneTwenty"]["speed"]) < 1e-6
          and result["sixty"]["stopped"] and result["oneTwenty"]["stopped"] and result["noSlowGlide"],
          f"Inertia decay/thresholds differ from native or frame rate: {result}")
    for name in ["axisLock","marker","markerHidden","quickGlide","coastMoved","grabStopsGlide","altPan","pausedRelease","stoppedRelease","flingRelease","cancelStops",
                 "wheelPrevented","pinchRelease","staggeredLift","twistIgnored","safariTwistIgnored","noDuplicatePinch","safariNoCoast","disposed"]:
        check(result[name], f"Navigation input regression ({name}): {result}")
    check(result["nativeMouseZoom"] is not None, f"An accelerated mouse wheel panned instead of zooming: {result}")
    check(abs(result["mouseZoom"]-0.904837418) < 1e-6 and abs(result["pixelMouseZoom"]-0.904837418) < 1e-6 and abs(result["nativeMouseZoom"]-0.904837418) < 1e-6
          and close(result["trackpadPan"],[-9,6]) and abs(result["modifierMomentum"]-0.818730753) < 1e-6,
          f"Mouse wheel or precise trackpad input is incorrect: {result}")
    check(abs(result["pinchZoom"]-0.904837418) < 1e-6 and result["pinchAnchor"] < 1e-6
          and close(result["touchPan"],[10,15]) and abs(result["touchPinch"]-0.5) < 1e-6 and result["touchAnchor"] < 1e-6 and result["pinchCoastAnchor"] < 1e-6
          and abs(result["twistDistanceRatio"]-1) < 1e-6 and abs(result["safariPinch"]-0.5) < 1e-6,
          f"Multitouch pan or pinch is incorrect, or twisting changed the view: {result}")
    check(abs(result["buttonZoom"]-0.25) < 1e-3, f"Zoom buttons zoomed by the wrong amount: {result['buttonZoom']}")
    check(not page.errors, f"Navigation errors: {page.errors}")
    page.page.context.close()


def test_touch_navigation(browser, base_url):
    """Navigate the actual mobile viewer without scrolling the page or breaking its controls."""
    page = CustomizerPage(browser.new_page(viewport={"width":390,"height":844}, has_touch=True, is_mobile=True),base_url)
    page.open()
    page.page.evaluate('''async () => {
        const THREE = await import("three");
        const original = THREE.Camera.prototype.updateMatrixWorld;
        THREE.Camera.prototype.updateMatrixWorld = function (...args) {
            const result = original.apply(this,args);
            if (this.isPerspectiveCamera && this.parent?.isScene) window.touchCamera = this;
            return result;
        };
        window.touchPose = () => ({position:window.touchCamera.position.toArray(),quaternion:window.touchCamera.quaternion.toArray()});
        window.touchPick = (x,y) => {
            const canvas = document.querySelector("#viewer canvas"), rect = canvas.getBoundingClientRect();
            const ray = new THREE.Raycaster();
            ray.setFromCamera(new THREE.Vector2((x-rect.left)/rect.width*2-1,1-(y-rect.top)/rect.height*2),window.touchCamera);
            const root = window.touchCamera.parent.children.find(c => c.isGroup && c.children.some(child => child.isMesh));
            const meshes = []; root.traverse(c => { if(c.isMesh && !c.isLineSegments2) meshes.push(c); });
            window.touchPivot = ray.intersectObjects(meshes,false)[0].point.clone();
        };
        window.touchProjection = () => {
            const rect = document.querySelector("#viewer canvas").getBoundingClientRect();
            const p = window.touchPivot.clone().project(window.touchCamera);
            return [rect.left+(p.x+1)*rect.width/2,rect.top+(1-p.y)*rect.height/2];
        };
    }''')
    page.page.wait_for_function("window.touchCamera")
    start = page.page.evaluate("window.touchPose()")
    canvas = page.page.locator("#viewer canvas").bounding_box()
    x,y = round(canvas["x"]+canvas["width"]/2),round(canvas["y"]+canvas["height"]/2)
    chromium = browser.browser_type.name == "chromium"
    if chromium:
        session = page.page.context.new_cdp_session(page.page)

        def contacts(kind, points):
            session.send("Input.dispatchTouchEvent", {"type":kind,"touchPoints":[
                {"id":i+1,"x":px,"y":py,"radiusX":4,"radiusY":4,"force":1} for i,(px,py) in enumerate(points)
            ]})
    else:
        # WebKit's automation protocol has no multi-touch injector. Dispatch the equivalent Pointer
        # Events through the real viewer; hardware capture is separately covered by Chromium above.
        page.page.evaluate('''() => {
            const canvas=document.querySelector("#viewer canvas");
            canvas.setPointerCapture=()=>{}; canvas.hasPointerCapture=()=>false;
            window.touchContacts=[];
        }''')

        def contacts(kind, points):
            page.page.evaluate('''({kind,points}) => {
                const canvas=document.querySelector("#viewer canvas"), previous=window.touchContacts;
                const type={touchStart:"pointerdown",touchMove:"pointermove",touchEnd:"pointerup",touchCancel:"pointercancel"}[kind];
                const current=points.length ? points : previous;
                current.forEach(([x,y],i) => canvas.dispatchEvent(new PointerEvent(type,{
                    bubbles:true,cancelable:true,pointerType:"touch",pointerId:100+i,button:0,buttons:kind==="touchEnd" ? 0 : 1,
                    clientX:x,clientY:y
                })));
                window.touchContacts=points;
            }''', {"kind":kind,"points":points})

    def reset_pose():
        # A new stationary grab cancels inertia, then restore the fixture's default view.
        contacts("touchStart",[(x,y)])
        contacts("touchEnd",[])
        page.page.evaluate('''pose => {
            window.touchCamera.position.fromArray(pose.position);
            window.touchCamera.quaternion.fromArray(pose.quaternion);
            window.touchCamera.updateMatrixWorld();
        }''',start)

    contacts("touchStart",[(x,y)])
    for i in range(1,9):
        contacts("touchMove",[(x+i*6,y+i*3)])
    contacts("touchEnd",[])
    orbit = page.page.evaluate("window.touchPose()")
    check(sum(a*b for a,b in zip(start["quaternion"],orbit["quaternion"])) < 0.99, "A one-finger drag didn't orbit")
    reset_pose()
    page.page.evaluate("([x,y]) => window.touchPick(x,y)",[x,y])
    contacts("touchStart",[(x-30,y),(x+30,y)])
    for i in range(1,9):
        contacts("touchMove",[(x-30+i,y+i*1.5),(x+30+i,y+i*1.5)])
    # Holding still before release must suppress a fling.
    page.page.wait_for_timeout(100)
    contacts("touchEnd",[])
    pan = page.page.evaluate("window.touchPose()")
    projected = page.page.evaluate("window.touchProjection()")
    check(abs(projected[0]-(x+8)) < 0.1 and abs(projected[1]-(y+12)) < 0.1, f"Two-finger pan lost its anchor: {projected}")
    check(abs(sum(a*b for a,b in zip(start["quaternion"],pan["quaternion"]))-1) < 1e-6, "Two-finger pan changed orientation")
    page.page.wait_for_timeout(100)
    resting = page.page.evaluate("window.touchPose()")
    check(max(abs(a-b) for a,b in zip(pan["position"],resting["position"])) < 1e-6, "A paused touch release still flung the view")
    reset_pose()
    page.page.evaluate("([x,y]) => window.touchPick(x,y)",[x,y])
    pivot = page.page.evaluate("window.touchPivot.toArray()")
    before = sum((a-b)**2 for a,b in zip(start["position"],pivot))**0.5
    contacts("touchStart",[(x-30,y),(x+30,y)])
    for i in range(1,9):
        contacts("touchMove",[(x-30-i*3,y),(x+30+i*3,y)])
    pinch = page.page.evaluate("window.touchPose()")
    after = sum((a-b)**2 for a,b in zip(pinch["position"],pivot))**0.5
    check(abs(after/before-30/54) < 1e-5, f"Two-finger pinch used the wrong scale: {after/before}")
    contacts("touchEnd",[])
    page.page.wait_for_timeout(100)
    projected = page.page.evaluate("window.touchProjection()")
    check(abs(projected[0]-x) < 0.1 and abs(projected[1]-y) < 0.1, f"Pinch inertia introduced sideways drift: {projected}")
    check(page.page.evaluate("window.scrollY") == 0, "Navigating the model scrolled the page")
    reset_pose()
    contacts("touchStart",[(x,y)])
    contacts("touchMove",[(x+10,y+10)])
    contacts("touchCancel",[])
    cancelled = page.page.evaluate("window.touchPose()")
    page.page.wait_for_timeout(100)
    resting = page.page.evaluate("window.touchPose()")
    check(max(abs(a-b) for a,b in zip(cancelled["position"],resting["position"])) < 1e-6, "Cancelled touch input kept moving")
    expect(page.page.locator("#download")).to_be_enabled()
    expect(page.page.locator("#axis-indicator")).to_be_visible()
    # The zoom buttons zoom toward the view's center, and the reset button returns to the starting view
    reset_pose()
    page.page.locator("#zoom-in").click()
    page.page.wait_for_timeout(400)
    zoomed = page.page.evaluate("window.touchPose()")
    check(sum((a-b)**2 for a,b in zip(zoomed["position"],start["position"])) > 1e-6
          and abs(sum(a*b for a,b in zip(start["quaternion"],zoomed["quaternion"]))-1) < 1e-6,
          "Zoom in didn't zoom, or turned the view")
    contacts("touchStart",[(x,y)])
    for i in range(1,9):
        contacts("touchMove",[(x+i*6,y+i*3)])
    contacts("touchEnd",[])
    page.page.wait_for_timeout(100)
    page.page.locator("#reset-view").click()
    page.page.wait_for_timeout(100)
    home = page.page.evaluate("window.touchPose()")
    check(max(abs(a-b) for a,b in zip(home["position"]+home["quaternion"],start["position"]+start["quaternion"])) < 1e-6,
          f"Reset view didn't return to the starting view: {home} vs {start}")
    check(not page.errors, f"Touch navigation errors: {page.errors}")
    if chromium:
        session.detach()
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
    # On a phone, Download sits in a bar right below the model view, and the credit below the settings
    download = page.page.locator("#download").bounding_box()
    check(download["y"] >= viewer["y"] + viewer["height"] - 1, "Download isn't below the mobile model view")
    settings = page.page.locator("aside").bounding_box()
    credit = page.page.locator(".credit").bounding_box()
    check(credit["y"] >= settings["y"] + settings["height"] - 1, "The credit isn't below the mobile settings")
    # On its side, a phone keeps the columns, rather than a wide and thin model view
    page.page.set_viewport_size({"width": 667, "height": 375})
    settings = page.page.locator("aside").bounding_box()
    viewer = page.page.locator("#viewer").bounding_box()
    check(settings["x"] + settings["width"] <= viewer["x"] + 1 and abs(viewer["height"] - 375) < 1,
          f"A phone on its side doesn't get columns: {settings}, {viewer}")
    # There, Download and the credit move into the sidebar, so that the view keeps its height
    # The page moves them when the layout changes, which can land a moment after the resize
    page.page.wait_for_function("""() => ["#download", ".credit"].every(selector =>
        document.querySelector(selector).closest("aside") !== null)""", timeout=5000)
    download = page.page.locator("#download").bounding_box()
    check(download["y"] + download["height"] <= 375 + 1 and download["x"] + download["width"] <= viewer["x"] + 1,
          f"Download isn't in reach at the bottom of the sidebar: {download}")
    page.page.set_viewport_size({"width": 390, "height": 844})
    page.page.wait_for_function("""() => document.querySelector("#download").closest("main") !== null""", timeout=5000)
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

    page.context.route("**/worker.js*", serve)  # the plugin adds a version to the address
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
        # Parameters are sent by opaque key, so the build with Width 65 is found by that value
        workers = faulty_worker(page.page, f'if (data.type === "build" && Object.values(data.parameters).includes(65)) {{ {fault} }}')
        downloads = []
        page.page.on("request", lambda request: downloads.append(request.url) if "model.wasm" in request.url else None)
        # Track the actual worker so a delayed message from a terminated generation can be replayed.
        page.page.add_init_script('''
            const NativeWorker = Worker;
            window.workers = [];
            window.Worker = class extends NativeWorker {
                constructor(...args) { super(...args); window.workers.push(this); }
                postMessage(data, ...args) { this.lastRequest = data; this.lastPost = performance.now(); super.postMessage(data, ...args); }
            };
        ''')
        page.open()
        if name == "cancel":
            # A rebuild only shows that it's building once it has taken a moment, so quick ones don't flicker
            page.page.evaluate("""() => new MutationObserver(() => {
                if (!document.getElementById("build-progress").hidden) window.progressShownAt ??= performance.now();
            }).observe(document.getElementById("build-progress"), { attributes: true })""")
            # Changing a value disables Download at once, but it only looks disabled once the
            # rebuild has taken a moment, so quick rebuilds don't make it flicker
            state = page.number_field("Width").evaluate("""field => {
                field.value = "65";
                field.dispatchEvent(new Event("change", { bubbles: true }));
                const download = document.getElementById("download");
                return { disabled: download.disabled, opacity: getComputedStyle(download).opacity };
            }""")
            check(state == {"disabled": True, "opacity": "1"}, f"Download changed its look at once: {state}")
            page.page.wait_for_function("getComputedStyle(document.getElementById('download')).opacity === '0.5'")
        else:
            page.set_number("Width", "65")
        if name == "cancel":
            expect(page.page.locator("#cancel")).to_be_visible()
            delay = page.page.evaluate("window.progressShownAt - window.workers[0].lastPost")
            check(delay >= 350, f"The building indicator showed {delay:.0f} ms into a rebuild, before its delay")
            page.page.wait_for_function('Object.values(window.workers[0].lastRequest.parameters ?? {}).includes(65)')
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
            expect_recovery(page, "couldn't be built")
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

        page.page.context.route(f"**/{resource}*", fail_first)
        page.page.goto(f"{base_url}/index.html#model=plate")
        expect_recovery(page, "worker stopped unexpectedly" if resource == "worker.js" else "Couldn't load")
        expect(page.page.locator("#reset")).to_be_hidden()
        page.rebuild(lambda: page.page.locator("#retry").click())
        expect(page.number_field("Width")).to_have_value("40")
        check(abs(page.download().extent(0) - 40) < 0.01, f"Retry after loading {resource} didn't build the model")
        check(not page.errors, f"Loading recovery had page errors: {page.errors}")
        page.page.context.close()

    # The page's own code failing to load, from the page's folder or the CDN, says so and offers a reload
    for failing in ["**/axes.js*", "https://cdn.jsdelivr.net/npm/three@*/build/three.module.js"]:
        page = CustomizerPage(browser.new_page(), base_url)
        page.page.context.route(failing, lambda route: route.abort())
        page.page.goto(f"{base_url}/index.html")
        expect(page.page.locator("#status")).to_contain_text("Couldn't load the page")
        expect(page.page.locator("#alert")).to_be_visible()
        expect(page.page.locator("#retry")).to_have_text("Reload")
        page.page.context.unroute(failing)
        page.page.locator("#retry").click()
        page.wait_for_build()
        page.page.context.close()

    page = CustomizerPage(browser.new_page(), base_url)
    workers = faulty_worker(page.page, 'if (data.type === "load") { while (true) {} }')
    page.page.goto(f"{base_url}/index.html")
    expect(page.page.locator("#cancel")).to_be_visible()
    page.page.locator("#cancel").click()
    expect_recovery(page, "Loading cancelled")
    page.rebuild(lambda: page.page.locator("#retry").click())
    check(len(workers) == 2, "Cancelling loading didn't restart the worker")
    check(abs(page.download().extent(0) - 40) < 0.01, "Retrying after cancelling loading didn't build the model")
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


def test_model_session(browser, base_url):
    """The model's instance is kept between requests, so that later builds reuse its geometry cache,
    and what it builds matches what a new instance builds."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.page.goto(f"{base_url}/index.html")
    result = page.page.evaluate('''async () => {
        const { ModelSession, fetchModel, fetchResources } = await import("./runner.js");
        const module = await WebAssembly.compile(await fetchModel(new URL("model.wasm", location.href).href));
        const resources = await fetchResources(location.href);
        const session = new ModelSession(module, resources);
        const listed = await session.listParameters();
        const instance = session.instance;
        // Values by label, as the catalog's keys, which parameters are identified by
        const keyed = (catalog, model, values) => Object.fromEntries(Object.entries(values).map(([label, value]) =>
            [catalog.models.find((m) => m.name === model)?.parameters.find((p) => p.label === label)?.key ?? label, value]));

        const encode = (data) => data && btoa(Array.from(data, (byte) => String.fromCharCode(byte)).join(""));
        const builds = [];
        for (const [model, values] of [
            ["plate", { Width: 55 }], ["spacer", { Height: 9 }], ["plate", { Width: 70, Holes: 4 }],
            ["nonexistent", {}], ["plate", { Width: 55 }],
        ]) {
            const kept = await session.build(model, keyed(listed.catalog, model, values));
            const fresh = await new ModelSession(module, resources).build(model, keyed(listed.catalog, model, values));
            builds.push({ model, exitCode: kept.exitCode, sameInstance: session.instance === instance,
                kept: encode(kept.data), fresh: encode(fresh.data) });
        }
        // Pruning empties the cache down to its limit, and what's pruned is built again when needed
        const cachedBytes = session.cacheByteCount();
        session.pruneCache(0);
        const prunedBytes = session.cacheByteCount();
        const rebuilt = await session.build("plate", keyed(listed.catalog, "plate", { Width: 55 }));
        const fresh = await new ModelSession(module, resources).build("plate", keyed(listed.catalog, "plate", { Width: 55 }));
        const pruning = { cachedBytes, prunedBytes, rebuiltBytes: session.cacheByteCount(),
            sameInstance: session.instance === instance, matches: encode(rebuilt.data) === encode(fresh.data) };
        return { listed: listed.catalog !== null, suspended: instance !== null, builds, pruning };
    }''')
    check(result["listed"] and result["suspended"], "Listing the parameters didn't leave the model's instance running")
    for build in result["builds"]:
        name = build["model"]
        check(build["sameInstance"], f"Building {name} replaced the model's instance")
        check(build["exitCode"] == 0, f"Building {name} in the kept instance failed")
        if build["fresh"] is None:
            check(build["kept"] is None, f"The kept instance built {name}, but a new one didn't")
            continue
        check(build["kept"] == build["fresh"], f"The kept instance built {name} differently from a new instance")
    pruning = result["pruning"]
    check(pruning["cachedBytes"] > 0, f"The model's cache reported no size after building: {pruning}")
    check(pruning["prunedBytes"] == 0, f"Pruning the cache to nothing left some of it: {pruning}")
    check(pruning["rebuiltBytes"] > 0 and pruning["sameInstance"], f"Building after pruning didn't refill the same instance's cache: {pruning}")
    check(pruning["matches"], "Building after pruning made a different preview from a new instance")
    check(not page.errors, f"The model session had page errors: {page.errors}")
    page.page.context.close()


def test_preview_matches_3mf(browser, base_url):
    """A build's preview shows exactly what the model's 3MF file holds: the same meshes, triangles,
    materials and outlines."""
    page = CustomizerPage(browser.new_page(), base_url)
    page.page.goto(f"{base_url}/index.html")
    mismatches = page.page.evaluate('''async () => {
        const { read3MF } = await import("./threemf.js");
        const { readPreview } = await import("./preview.js");
        const { ModelSession, fetchModel, fetchResources } = await import("./runner.js");
        const module = await WebAssembly.compile(await fetchModel(new URL("model.wasm", location.href).href));
        const session = new ModelSession(module, await fetchResources(location.href));
        const { catalog } = await session.listParameters();
        // Values by label, as the catalog's keys, which parameters are identified by
        const keyed = (catalog, model, values) => Object.fromEntries(Object.entries(values).map(([label, value]) =>
            [catalog.models.find((m) => m.name === model)?.parameters.find((p) => p.label === label)?.key ?? label, value]));
        const buffer = (data) => data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
        const describe = (group) => group.children.map((mesh) => ({
            indices: Array.from(mesh.geometry.index.array),
            color: mesh.material.color.getHexString(), opacity: mesh.material.opacity,
            metalness: mesh.material.metalness, roughness: mesh.material.roughness,
            edges: mesh.children.map((edges) => edges.geometry.attributes.position.count),
        }));
        const positions = (group) => group.children.flatMap((mesh) => Array.from(mesh.geometry.attributes.position.array));

        const mismatches = [], sizes = [];
        for (const [model, values] of [["plate", {}], ["spacer", { Width: 30 }], ["plate", { Holes: 0, Corners: "square" }]]) {
            const label = `${model} ${JSON.stringify(values)}`;
            const built = await session.build(model, keyed(catalog, model, values));
            const exported = await session.export(model, keyed(catalog, model, values));
            sizes.push(built.data?.length);
            if (!built.fileName?.endsWith(".cadovapreview")) mismatches.push(`${label}: built ${built.fileName}, not a preview`);
            if (!exported.fileName?.endsWith(".3mf")) mismatches.push(`${label}: exported ${exported.fileName}, not a 3MF file`);
            if (mismatches.length) continue;
            const preview = readPreview(buffer(built.data), "#ffffff"), file = read3MF(buffer(exported.data), "#ffffff");
            if (JSON.stringify(describe(preview)) !== JSON.stringify(describe(file))) mismatches.push(`${label}: meshes or materials`);
            const [a, b] = [positions(preview), positions(file)];
            if (a.length !== b.length || a.some((value, index) => Math.abs(value - b[index]) > 1e-4)) mismatches.push(`${label}: vertices`);
        }
        // The values have to reach the model, or every build would be the default one
        if (sizes[0] === sizes[2]) mismatches.push("changed values made the same plate as the defaults");
        return mismatches;
    }''')
    check(not mismatches, f"Previews differ from the 3MF files: {mismatches}")
    check(not page.errors, f"Comparing previews had page errors: {page.errors}")
    page.page.context.close()


# Chromium renders WebGL in software where there's no GPU, such as on CI machines
CHROMIUM_ARGUMENTS = ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]


def main(arguments):
    # Arguments are browser engines, and optionally the names of tests to run, such as test_navigation
    engines = [argument for argument in arguments if not argument.startswith("test")] or ["chromium"]
    only = {argument for argument in arguments if argument.startswith("test")}
    check(CUSTOMIZER.joinpath("model.wasm").exists(), f"No customizer in {CUSTOMIZER}; generate it first")
    server = TestServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=CUSTOMIZER))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f"http://127.0.0.1:{server.server_address[1]}"

    failed = False
    cdn = CDNCache()
    with sync_playwright() as playwright:
        runs = [(engine, run, []) for engine in engines for run in (
            test, test_tabs, test_dynamic_parameters, test_model_menu, test_single_model, test_grid, test_grid_theme, test_viewer_defaults, test_grid_navigation, test_line_rendering, test_sharp_edges, test_lighting, test_navigation, test_touch_navigation, test_axes, test_worker_recovery, test_loading_recovery, test_worker_timeouts, test_model_session, test_preview_matches_3mf,
        ) if not only or run.__name__ in only]
        if "chromium" in engines and (not only or "test_without_webgl" in only):
            runs.append(("chromium", test_without_webgl, ["--disable-webgl", "--disable-3d-apis"]))
        for engine, run, arguments in runs:
            name = f"{engine} ({run.__name__})"
            launcher = getattr(playwright, engine)
            browser = cdn.browser(launcher.launch(args=(CHROMIUM_ARGUMENTS if engine == "chromium" else []) + arguments))
            start = time.monotonic()
            try:
                run(browser, base_url)
                print(f"{name}: passed in {time.monotonic() - start:.1f} s")
            except (AssertionError, PlaywrightError) as error:
                print(f"{name}: FAILED after {time.monotonic() - start:.1f} s: {error}")
                failed = True
            finally:
                browser.close()
    server.shutdown()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
