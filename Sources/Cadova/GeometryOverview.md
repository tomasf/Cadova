# Geometry Architecture, internal overview

Abstract  `--build-->`  Node  `--evaluate-->`  Concrete

Cadova separates geometry into **three layers**, each serving a specific purpose in the modeling pipeline:

---

### 1. Abstract Geometry
- **Type**: `Geometry` a.k.a. `Dimensionality.Geometry`, plus the higher-level `Shape2D`/`Shape3D`
- **Audience**: Public API
- **Purpose**: High-level, declarative geometry definition.

Example:
```swift
Box(x: 10, y: 10, z: 5)
    .subtracted {
        Cylinder(diameter: 4, height: 10)
    }
```

---

### 2. Geometry Nodes
- **Type**: `GeometryNode` a.k.a. `Dimensionality.Node`
- **Audience**: Internal
- **Purpose**: Intermediate representation for structure, caching, and traversal.
- **Transition**: Built from abstract geometry via `build(in:context:)`, given an environment and evaluation context.

Example:

```swift
GeometryNode3D.boolean([
    .shape(.box(size: Vector3D(10, 10, 5))),
    .shape(.cylinder(bottomRadius: 2, topRadius: 2, height: 10, segmentCount: 100))
], type: .difference)
```

debugDescription:
```
difference {
    box(x: 10, y: 10, z: 5)
    cylinder(bottom R: 2, top R: 2, height: 10, segments: 100)
}
```


---

### 3. Concrete Geometry
- **Type**: `Manifold`, `CrossSection` a.k.a. `Dimensionality.Concrete`
- **Audience**: Internal, runtime
- **Purpose**: Evaluated mesh geometry with real vertices, used for export and slicing.
- **Transition**: Evaluated from nodes via `evaluate(in:)`, given an evaluation context.