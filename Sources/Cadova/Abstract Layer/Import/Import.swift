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
/// The colors and materials of a 3MF file come along with its geometry. Each face keeps the color,
/// base material or composite material the file gives it, including metallic display properties,
/// with multiproperties blended into one material per face. They're written back out on export the
/// same way ``Geometry/colored(_:)`` ones are. Apply ``Geometry/colored(_:)`` or
/// ``Geometry/withMaterial(_:)`` to the import to replace them, or ``Geometry/withoutMaterials()``
/// to drop them. A face has a single material here, so a triangle whose vertices name different
/// properties takes its first vertex's. Textures have no counterpart in Cadova and are left out.
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
