# Publishing a Web Customizer

Turn a parametric model into a web page where anyone can adjust its parameters, see a live 3D preview and download a 3MF file.

## Overview

The `generate-customizer` command builds a web customizer for one of your models. The result is a folder of static files that you can put on any web server. When a visitor opens the page, a form lets them change the model's parameters, a 3D preview updates as they do, and a button downloads the finished model as a 3MF file, ready for a slicer.

The model runs entirely in the visitor's browser, compiled to WebAssembly. There's no server doing the work, so any static hosting will do: GitHub Pages, Netlify, an S3 bucket or a folder on your own web server.

## Preparing Your Model

A customizer offers whatever parameters your model declares with ``Parameter``. Give each one a label, which is what the page calls it, and a default value. A range, a step and a description, wherever they make sense, help the page offer the right controls:

```swift
enum Quality: String, CaseIterable, ParameterValue {
    case draft, standard, fine
}

struct Scoop: Geometry3D {
    @Parameter("Volume", in: 20...100, step: 1, description: "How much the scoop holds, in milliliters")
    var volume = 30.0

    @Parameter("Hanging hole", description: "Put a hole in the end of the handle for hanging it up")
    var hangingHole = true

    @Parameter("Quality", description: "Smoothness of the curved surfaces. Draft builds fastest.")
    var quality = Quality.standard

    var body: any Geometry3D {
        // ...
    }
}
```

Each type of parameter gets its own kind of control:

| Parameter type | Control |
|---|---|
| `Double`, `Int` | A number field, plus a slider when the parameter has a range |
| `Angle` | A number field in degrees, plus a slider when the parameter has a range |
| `Bool` | A switch |
| A `CaseIterable` string enum | Buttons for up to four cases, a menu for more |
| `String` | A text field |

The page shows each parameter's label with its description below it. Within a model, the label also identifies the parameter, so parameters with the same label in one model are one parameter with one control. When you build a model yourself, its parameters simply have their default values.

The page's heading and introduction come from the model's ``Metadata``:

```swift
await Project {
    await Model("scoop") {
        Metadata(title: "Coffee Scoop", description: "A scoop that holds an exact amount of coffee.")
        Scoop()
    }
}
```

### Several Models

When a project has more than one model with parameters, the page gets a tab for each, so visitors can switch between them. The project's own ``Metadata`` provides the page's heading and introduction, and each model's title names its tab. A model without a title of its own is named after the model instead:

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

To find a model's parameters, Cadova builds it with the default values and records every parameter that's created or read along the way. A parameter that only exists in a branch the defaults don't take won't be found, so declare parameters as stored properties of your geometry types, where they're always created.

## Installing the Toolchain

Building for WebAssembly needs the Swift 6.4.0 toolchain from swift.org. The Swift that comes with Xcode can't be used for this, even when it's the same version. Install it with [swiftly](https://www.swift.org/install):

```
$ swiftly install 6.4.0
```

If swiftly can't find 6.4.0, update it first with `swiftly self-update`. On macOS, you can also install [swift.org's package](https://download.swift.org/swift-6.4.0-release/xcode/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-osx.pkg) directly. You don't need to switch to this toolchain for your everyday work; the command finds it by itself. If you've installed it somewhere unusual, set `CADOVA_WASM_TOOLCHAIN` to the toolchain's directory, the one that contains `usr/bin`.

Building customizers works on macOS and Linux.

## Generating the Customizer

Run the command from your package's directory:

```
$ swift package generate-customizer
```

The command is a SwiftPM plugin that comes with Cadova, so any package that depends on Cadova has it. The first time, it asks for two permissions: to connect to the network, to download Swift's WebAssembly SDK and Binaryen, which shrinks the result; and to write the customizer into your package. When there's no terminal to ask in, such as in CI, grant them with options instead:

```
$ swift package --allow-network-connections all:443 --allow-writing-to-package-directory generate-customizer
```

The first run also compiles Cadova and its dependencies for WebAssembly, which takes a few minutes. Later runs only rebuild what changed. The downloads and build products are kept in your package's `.build` directory.

The command takes these options:

- `--product NAME` picks the executable product to build, if your package has more than one.
- `--model NAME` limits the page to a single model, without tabs. Without it, the page offers every model that has parameters.
- `--output DIR` picks where the customizer goes. The default is `Customizer` in your package.

## Previewing Locally

The page doesn't work when opened directly from disk, because browsers block the requests it makes to load the model. Serve the folder over HTTP to try it:

```
$ python3 -m http.server --directory Customizer 8000
```

Then open `http://localhost:8000`. If a build fails, the page's build log shows the model's output.

## Publishing

Upload the contents of the folder to any static web host. It holds five files: the page, three scripts and `model.wasm`, which is the model itself.

`model.wasm` is about 18 MB, but it compresses well: about 6.6 MB with gzip and 4.8 MB with Brotli. Most hosts compress files on the fly, but check that yours does so for `.wasm` files, or visitors download the full size. The page also loads three.js, which draws the preview, and a small WASI library from the jsDelivr CDN, so visitors need to be able to reach it.

When a visitor changes a parameter or switches tabs, the page's address changes to match, after the `#`. A link copied from the address bar opens the customizer on the same tab with the same settings, which makes it easy to share a particular configuration.

## Limitations

A model runs differently in a browser than on your computer, so a few things don't work yet:

- ``Text`` can't be rendered, because it looks for fonts installed on the system, and there are none in the browser.
- ICU's data, which formats dates and numbers for different locales, is left out to save 34 MB. Code that needs it, such as `DateFormatter` and `NumberFormatter`, stops the build.
- Models build on a single thread, so complex models take longer than they do natively.
- The preview shows the model's shape in a single color. The downloaded 3MF file keeps the model's parts and materials.

## See Also

- <doc:ModelAndProject>
