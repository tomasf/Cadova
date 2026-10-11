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
            return read3MF(bytes.buffer, "#d9d4c7").children.map(({ material }) => ({
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
    check(not page.errors, f"The page had errors without WebGL: {page.errors}")


# Chromium renders WebGL in software where there's no GPU, such as on CI machines
CHROMIUM_ARGUMENTS = ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]


def main(engines):
    check(CUSTOMIZER.joinpath("model.wasm").exists(), f"No customizer in {CUSTOMIZER}; generate it first")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=CUSTOMIZER))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f"http://127.0.0.1:{server.server_address[1]}"

    failed = False
    with sync_playwright() as playwright:
        runs = [(engine, run, []) for engine in engines for run in (test, test_tabs, test_single_model)]
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
