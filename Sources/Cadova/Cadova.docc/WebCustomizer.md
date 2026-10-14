# Publishing a Web Customizer

Turn a parametric model into a web page where anyone can adjust its parameters, see a live 3D preview and download the result.

## Overview

The `generate-customizer` command builds a web customizer for one of your models. The result is a folder of static files that you can put on any web server. When a visitor opens the page, a form lets them change the model's parameters, a 3D preview updates as they do, and a button downloads the finished model in the format you set with ``ModelOptions/format3D(_:)`` or ``ModelOptions/format2D(_:)``. A 2D model downloads as SVG unless you choose a format.

The model runs entirely in the visitor's browser, compiled to WebAssembly. There's no server doing the work, so any static hosting will do: GitHub Pages, Netlify, an S3 bucket or a folder on your own web server.

## Preparing Your Model

A customizer offers whatever parameters your model declares with ``Parameter``. Give each one a label, which is what the page calls it, and a default value. A range, a step, a unit and a description, wherever they make sense, help the page offer the right controls:

```swift
struct Scoop: Geometry3D {
    @Parameter("Volume", in: 20...100, step: 1, unit: "ml", description: "How much the scoop holds")
    var volume = 30.0

    @Parameter("Hanging hole", description: "Put a hole in the end of the handle for hanging it up")
    var hangingHole = true

    @Parameter("Quality", description: "Smoothness of the curved surfaces. Draft builds fastest.")
    var quality = Quality.standard

    var body: any Geometry3D {
        // ...
    }
}

enum Quality: String, CaseIterable, ParameterValue {
    case draft, standard, fine
}
```

Each type of parameter gets its own kind of control:

| Parameter type | Control |
|---|---|
| `Double`, `Int` | A number field, plus a slider when the parameter has a range, and the unit after it if the parameter has one |
| `Angle` | A number field in degrees, plus a slider when the parameter has a range |
| `Bool` | A switch |
| ``Color`` | A color picker |
| A `CaseIterable` string enum | Buttons for up to four cases, a menu for more |
| `String` | A text field |

A parameter is identified by where it's declared, not by its label, so you're free to reword labels. When you build a model yourself, its parameters have their default values.

The page's heading and introduction come from the model's ``Metadata``:

```swift
await Model("scoop") {
    Metadata(title: "Coffee Scoop", description: "A scoop that holds an exact amount of coffee.")
    Scoop()
}
```

### Several Models

When a project has more than one model with parameters, the page gets a tab for each, in the order they're declared, so visitors can switch between them. The project's own ``Metadata`` provides the page's heading and introduction, or without a title, the page is named after your executable product. Each model's title names its tab. A model without a title of its own is named after the model instead:

```swift
await Project {
    Metadata(title: "Kitchen Set", description: "A jar and a lid that fit together.")

    await Model("jar") {
        Metadata(title: "Jar", description: "Holds about half a liter.")
        Jar()
    }
    await Model("lid") {
        Lid()
    }
}
```

Each model keeps its own values. If the jar and the lid both have a "Diameter" parameter, changing it on one tab leaves the other alone.

To find a model's parameters, Cadova records every parameter that's created or read while the model builds, and it does so for every build. So a parameter that only matters for some choices appears on the page when it does, and goes away when it doesn't, keeping its value in case it comes back:

```swift
switch shape {
case .cylinder:
    @Parameter("Diameter", in: 20...150, unit: "mm") var diameter = 60.0
    Cylinder(diameter: diameter, height: height)
case .box:
    @Parameter("Width", in: 20...150, unit: "mm") var width = 80.0
    Box(x: width, y: width, z: height)
}
```

### Resources

Files your package includes as resources, with `.copy` or `.process` in its manifest, come along to the customizer, from your package and from its dependencies. Your code finds them through `Bundle.module` as it does natively, so nothing changes in how you read them:

```swift
.executableTarget(
    name: "Labels",
    dependencies: ["Cadova"],
    resources: [.copy("Inter-Bold.ttf")]
)
```

The page downloads every resource when it loads, so keep large files out of resources the model doesn't need. Look resources up without a subdirectory: in WebAssembly, Foundation currently gets the path wrong for a resource in a subdirectory, so copy files individually rather than as a folder.

Resources are also how to use text: ``Text`` normally finds fonts installed on the system, and the browser has none it can use. Include a font file as a resource and name it explicitly:

```swift
let font = Bundle.module.url(forResource: "Inter-Bold", withExtension: "ttf")
Text("Hello").withFont("Inter", style: "Bold", from: font)
```

Publishing a customizer distributes its resources, so only include fonts whose license allows that, such as fonts under the SIL Open Font License.

## Installing the Toolchain

Building for WebAssembly needs the Swift 6.4.0 toolchain from swift.org. The Swift that comes with Xcode can't be used for this, even when it's the same version. Install it with [swiftly](https://www.swift.org/install):

```
$ swiftly install 6.4.0
```

If swiftly can't find 6.4.0, update it first with `swiftly self-update`. On macOS, you can also install [swift.org's package](https://download.swift.org/swift-6.4.0-release/xcode/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-osx.pkg) directly. You don't need to switch to this toolchain for your everyday work; the command finds it by itself. If you've installed it somewhere unusual, set `CADOVA_WASM_TOOLCHAIN` to the toolchain's directory, the one that contains `usr/bin`.

On Windows, use [swift.org's installer](https://download.swift.org/swift-6.4.0-release/windows10/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-windows10.exe). SwiftPM can't build on Windows when several versions of Swift are installed side by side, so uninstall any others first.

Building customizers works on macOS, Linux and Windows.

## Generating the Customizer

Run the command from your package's directory:

```
$ swift package generate-customizer
```

The command comes with Cadova. It asks for permission to download Swift's WebAssembly SDK and Binaryen, and to write the customizer into your package. Where there's no terminal to ask in, such as in CI, grant them with options instead:

```
$ swift package --allow-network-connections all:443 --allow-writing-to-package-directory generate-customizer
```

The first run compiles Cadova and its dependencies for WebAssembly, which takes a few minutes. Later runs only rebuild what changed.

The command takes these options:

- `--product NAME` picks the executable product to build, if your package has more than one.
- `--model NAME` limits the page to a single model, without tabs. Without it, the page offers every model that has parameters.
- `--output DIR` picks where the customizer goes. The default is `Customizer` in your package.

## Previewing Locally

The page doesn't work when opened directly from disk, because browsers block the requests it makes to load the model. Serve the folder over HTTP to try it:

```
$ python3 -m http.server --directory Customizer 8000
```

Then open `http://localhost:8000`.

Anything your model prints with `print()` goes to the browser's console, along with each build's time and Cadova's warnings, so you can debug a model in the customizer much as you would natively. If a build fails, the page also shows the error over the model view.

## Publishing

Upload the whole generated folder to any static web host. `model.wasm` is about 18 MB but compresses to around 5 MB, so check that your host compresses `.wasm` files. The page loads three.js and a small WASI library from the jsDelivr CDN.

## Limitations

A model runs differently in a browser than on your computer, so a few things don't work yet:

- ``Text`` can only use fonts included as resources. Text that relies on system fonts fails to build.
- ICU's data, which formats dates and numbers for different locales, is left out to save 34 MB. Code that needs it, such as `DateFormatter` and `NumberFormatter`, stops the build.
- Models build on a single thread, so complex models take longer than they do natively.
- The browser gives a model less stack space, so a model that builds natively can still run out of it in the browser and fail.

## See Also

- <doc:ModelAndProject>
