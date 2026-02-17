# Troubleshooting

Common issues and how to resolve them.

## Can't See Your Geometry?

![A model with highlighted geometry for debugging](troubleshooting-highlighted)

When subtracting or combining shapes, parts may seem to disappear, often because they're not positioned correctly or look different than the way you expect. Use `.highlighted()` to make a shape stand out. Even subtracted geometry can be made visible in translucent red using this method.

```swift
Box(x: 20, y: 20, z: 5)
    .translated(x: 5)
    .subtracting {
        Cylinder(diameter: 10, height: 5)
            .highlighted() // helps spot if it's misaligned!
    }
```

## Running is Slow?

Complex models and high segment counts can slow down model generation. Here's how to improve performance.

### Use Release Mode

Release builds are dramatically faster than debug builds.

- **In Xcode**: Go to *Product → Scheme → Edit Scheme…*, then under the *Info* tab, change *Build Configuration* to *Release*.
- **In VS Code**: Click the *Run and Debug* button in the sidebar, and change from *Debug MyProject* to *Release MyProject* in the dropdown menu.
- **From the Command Line**: `swift run -c release`

This can often give 10× or greater speedups.

### Lower Segment Count

Curved shapes like cylinders, spheres, and paths use polygonal approximations. If you're using many or large shapes, consider reducing the number of segments. The default segmentation is `.adaptive(minAngle: 2°, minSize: 0.15)`. Increasing the angle and/or size results in fewer segments and more lightweight geometry.

```swift
myComplexGeometry
    .withSegmentation(minAngle: 5°, minSize: 0.3)
```

## Learn More

- **DocC documentation** is available in the Cadova package. ⌥-click a symbol in Xcode to view its documentation.
- **Have a question?** Start a thread in [GitHub Discussions](https://github.com/tomasf/Cadova/discussions).
