# Internals

Understand Cadova's layered architecture and how geometry is represented under the hood.

## Overview

If you're looking to contribute to Cadova or just want to understand how it works under the hood, it's helpful to understand how geometry is represented internally. Cadova uses a layered architecture with three main representations of geometry: abstract geometry, geometry nodes, and concrete geometry. Each layer builds on the previous one, getting progressively lower-level and closer to actual mesh data.

## Abstract Geometry

The types users interact with directly—like ``Box``, ``Sphere``, ``Stack``, ``Union``—are part of what we call abstract geometry. These types conform to the ``Geometry`` protocol, which defines a high-level, declarative description of a shape or operation. User-defined shapes also live here, by composing existing geometry types wrapped in a Shape.

The ``Geometry`` protocol is generic over a type called ``Dimensionality``, which distinguishes between 2D and 3D geometry. The concrete types `D2` and `D3` represent those dimensionalities and declare type aliases to associate with specific types like ``Vector2D``, `Transform2D`, and `Axis2D` (or their 3D equivalents). This allows geometry code to generalize over 2D and 3D while still relying on the right concrete types.

```swift
typealias Geometry2D = Geometry<D2>
typealias Geometry3D = Geometry<D3>
```

Every ``Geometry`` type implements a method called `build(in:context:)`, which, given an environment, produces the next representation: a geometry node. Many types conform to ``Shape2D`` or ``Shape3D``, which implement `build` automatically by delegating to a `body` property. This works similarly to how SwiftUI uses `View` and `body`.

Composing shapes is done by nesting geometry inside each other, often with result builders or method chaining. This produces a tree of geometry values that's both readable and reusable.

## Geometry Nodes

When abstract geometry is built, it turns into a tree of *geometry nodes*. This is a lower-level representation, designed to express geometry in terms of a small, fixed set of operations—roughly matching a subset of what the [Manifold library](https://github.com/elalish/manifold) supports.

There is a single `GeometryNode` type, generic over dimensionality. It supports a fixed set of primitives and operations such as shapes (e.g., ``Box``, ``Sphere``, ``Circle``...), boolean operations, transformations and extrusion.

Nodes are immutable and value-based. They're cheap to copy and pass around, and they conform to `Hashable`, which makes them ideal for caching. In fact, one of their main roles is to serve as keys in the geometry cache.

A single geometry node describes either a shape or an operation. More complex structures are built by nesting nodes together in a tree, where each node refers to its children.

## Concrete Geometry

The final representation is concrete geometry; actual polygonal data. This is where geometry becomes real. In 2D, this means a cross-section; in 3D, a manifold mesh. These are the types defined by the Manifold library and exposed in Cadova through the [Manifold-Swift](https://github.com/tomasf/manifold-swift) wrapper.

Generating concrete geometry is the most expensive part of the process, so Cadova avoids doing it more than once. Every geometry node that is evaluated is stored in a cache alongside its corresponding mesh. This makes repeated geometry use efficient.

For example, if you create a `Circle(diameter: 10)` multiple times in different parts of a model, given the same segmentation settings, Cadova will only generate the mesh once. Later, it reuses the cached result whenever it sees the same node again.

Caching becomes even more important for compound shapes. If you subtract something from a complex object, and then reuse that object again in a different way, the shared parts of the node tree can still come from the cache. Evaluation happens progressively—each operation only rebuilds the parts it needs, using the rest from cache.
