# What is Cadova?

Learn about Cadova's design philosophy, who it's for, and how it compares to existing tools.

## Overview

**Cadova** is a Swift library for constructing 3D models programmatically — with a focus on 3D printing. It combines the precision and parametric nature of code-based modeling with the power and elegance of Swift as a modern programming language. Cadova is cross-platform and runs on macOS, Linux, and Windows.

Traditional CAD tools rely on complex UIs and disconnected parametric workflows. Cadova lets you describe geometry entirely in Swift, making models more flexible, maintainable, and expressive. It's also open source, so you can dig into the internals or contribute improvements.

If you've used tools like OpenSCAD, you'll recognize the core idea, but Cadova takes it further.

## Why Cadova?

![A model showcasing Cadova's capabilities](what-is-cadova-openscad)

OpenSCAD introduced the concept of code-driven modeling, which many developers and tinkerers love, but it comes with significant limitations:

- A primitive language with weak support for abstraction or reuse
- Clunky syntax and lack of editor tooling
- Limited control structures and data types

Cadova takes the same core idea, building 3D models with code, but replaces the custom language with *Swift*, a modern language known for safety, clarity, and powerful DSL support. With Cadova, you get:

- A real programming language; no new syntax or learning curve if you already use Swift
- Clean, readable code that mirrors the structure of your model
- Precise, parametric control
- Strong editor support: autocomplete, navigation, refactoring, and debugging
- A foundation for building higher-level modeling libraries and tools

## Who is it for?

Cadova is for programmers who want to design physical objects. Most users are:

- Swift developers interested in 3D printing
- Makers and hobbyists who prefer code to GUIs
- People building custom mechanical parts
- Educators teaching geometry, 3D math, or manufacturing concepts

If you know Swift (or want to learn), and you want to build 3D models in a programmable, repeatable way, Cadova is for you.

## How is it used?

Here's a simple example of a parametric model:

![A parametric model example](what-is-cadova-example)

```swift
await Model("getting-started") {
    Box(x: 10, y: 10, z: 5)
        .cuttingEdgeProfile(.fillet(radius: 1), on: .top)
        .subtracting {
            Cylinder(radius: 1, height: 10)
                .translated(x: 5, y: 5)
        }
}
```

Under the hood, Cadova uses [Manifold](https://github.com/elalish/manifold) to build real, watertight meshes, meaning they're printable and free from typical mesh errors. There is no preview mode; generated models are full 3MF files and can be sent straight to your slicer or viewer.

Cadova also supports splitting models into named <doc:WorkingWithParts>, which appear as separate objects in the 3MF file. This is useful in viewers, where individual parts can be shown or hidden, and especially powerful in slicers, where each part can have its own print settings — like infill, speed, or supports.

## What Cadova isn't

Cadova is not an IDE or development environment. It doesn't come with a custom editor. Instead, you use your preferred tools: Xcode, VS Code, the command line, or anything else that builds and runs Swift. Cadova is also not a viewer or slicer. You write code and get 3MF files out, ready for viewing or slicing in any compatible tool. The focus is on modeling, not viewing or printing.

We do recommend [Cadova Viewer](https://github.com/tomasf/CadovaViewer), a native macOS app for viewing 3MF models. It automatically reloads the view when the underlying file changes, making it fast and seamless to iterate on designs.

## What's next?

Cadova is still growing. The long-term goal is to make Cadova a strong foundation for building custom modeling libraries. For example, the `Helical` package provides high-level tools for creating threads, bolts, and other helical features. Others are encouraged to build similar packages on top of Cadova's core.
