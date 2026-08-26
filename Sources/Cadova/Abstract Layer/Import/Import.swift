import Foundation

/// Imports geometry from an external file.
///
/// Use `Import` to bring in geometry from existing files. In 2D, SVG documents are supported:
///
/// ```swift
/// Import(svg: "drawing.svg")
/// Import(svg: url, scale: .pixels, origin: .native)
/// ```
///
/// In 3D, both 3MF and STL models are supported. 3MF files additionally support selecting
/// individual parts by name or part number; STL files are always imported as a single mesh.
///
/// ```swift
/// Import(model: "part.3mf")
/// Import(model: url, parts: [.name("Handle")])
/// ```
///
/// A closure form gives you each part of a 3MF file in turn, letting you leave parts out, route
/// them into ``Part``s or modify them as they're imported:
///
/// ```swift
/// Import(model: url) { geometry, part in
///     if part.name != "Support" {
///         geometry.inPart(Part(part.defaultName))
///     }
/// }
/// ```
///
/// > Important: Imported 3D models must be manifold (watertight, with consistently oriented,
/// > non-self-intersecting faces). Non-manifold geometry may fail or produce unexpected
/// > results in later operations.
///
public struct Import<D: Dimensionality>: Geometry {
    internal let makeBody: @Sendable () -> any Geometry<D>

    internal init(makeBody: @escaping @Sendable () -> any Geometry<D>) {
        self.makeBody = makeBody
    }

    public var body: any Geometry<D> {
        makeBody()
    }
}
