import Foundation

/// Imports geometry from an external file.
///
/// Use `Import` to bring in geometry from existing files. The supported formats depend on
/// the dimensionality:
///
/// **2D (SVG)**
/// ```swift
/// Import(svg: "drawing.svg")
/// Import(svg: url, unitMode: .pixels, origin: .topLeft)
/// ```
///
/// **3D (Models)**
/// - **3MF**: Full support including part selection by name or part number
/// - **STL**: Binary and ASCII formats (single mesh, no part selection)
///
/// ```swift
/// Import(model: "part.3mf")
/// Import(model: url, parts: [.name("Handle")])
/// ```
///
public struct Import<D: Dimensionality>: Shape {
    internal let makeBody: @Sendable () -> any Geometry<D>

    internal init(makeBody: @escaping @Sendable () -> any Geometry<D>) {
        self.makeBody = makeBody
    }

    public var body: any Geometry<D> {
        makeBody()
    }
}
