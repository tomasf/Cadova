"""Tests a generated web customizer in real browsers.

Generate the fixture's customizer first, then run this with the browser engines to test:

    cd Tests/Customizer/Fixture
    swift package --allow-network-connections all:443 --allow-writing-to-package-directory generate-customizer
    python3 ../test_customizer.py chromium webkit

It serves the customizer locally, loads the page, and checks that the form matches the model's
parameters, that changing them through the URL and through the form rebuilds the model, and that the
downloaded 3MF reflects each change.
"""

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
        status = self.page.locator("#status")
        expect(status).to_have_text(re.compile(r"^Built in \d+ ms$|failed|wasn't|couldn't|nothing"), timeout=TIMEOUT)
        if not status.text_content().startswith("Built in"):
            log = self.page.locator("#log").text_content()
            raise AssertionError(f"The build failed: {status.text_content()}\n{log}")

    def rebuild(self, action):
        """Runs an action that should rebuild the model, and waits for the new build."""
        self.page.evaluate("document.getElementById('status').textContent = ''")
        action()
        self.wait_for_build()

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
    expect(page.page.locator("#title")).to_have_text("Test Plate")
    expect(page.page.locator("#subtitle")).to_have_text("A plate for testing the web customizer.")
    for name in ["width", "holes", "thick"]:
        expect(page.page.locator(f"#parameter-{name}")).to_be_attached()
    expect(page.page.get_by_role("button", name="Rounded")).to_have_attribute("aria-pressed", "true")
    default = page.download()
    check(abs(default.extent(0) - 40) < 0.01, f"Default width is {default.extent(0)}, expected 40")
    check(abs(default.extent(2) - 3) < 0.01, f"Default thickness is {default.extent(2)}, expected 3")

    # Values in the URL hash override the defaults
    page.open("#width=80&thick=true")
    expect(page.page.locator("#parameter-width")).to_have_value("80")
    changed = page.download()
    check(abs(changed.extent(0) - 80) < 0.01, f"Width from the URL is {changed.extent(0)}, expected 80")
    check(abs(changed.extent(2) - 6) < 0.01, f"Thickness from the URL is {changed.extent(2)}, expected 6")

    # Changing a value in the form rebuilds the model and updates the URL
    page.rebuild(lambda: page.page.get_by_role("button", name="Square").click())
    check("corners=square" in page.page.url, f"The URL doesn't have the new value: {page.page.url}")
    square = page.download()
    check(square.triangles < changed.triangles,
          f"Square corners should need fewer triangles than rounded ones ({square.triangles} vs {changed.triangles})")
    check(abs(square.extent(0) - 80) < 0.01, "Changing the corners lost the width")

    def remove_holes():
        holes = page.page.locator("#parameter-holes")
        holes.fill("0")
        holes.blur()  # number fields report a change when they lose focus

    page.rebuild(remove_holes)
    no_holes = page.download()
    check(no_holes.triangles < square.triangles,
          f"Removing the holes should remove triangles ({no_holes.triangles} vs {square.triangles})")

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
        runs = [(engine, test, []) for engine in engines]
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
