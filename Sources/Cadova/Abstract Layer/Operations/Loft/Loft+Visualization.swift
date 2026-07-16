import Foundation

public extension Loft {
    /// Produces a visualization of the loft sections without performing the actual loft operation.
    ///
    /// Each section is shown as a thin extruded shape at its position along the loft's path, with each section
    /// colored distinctly to make it easy to identify individual sections. This is useful for debugging loft
    /// configurations and verifying that sections are positioned, oriented, and shaped as expected before running
    /// the full loft operation.
    ///
    /// The visualization shows:
    /// - Each 2D section shape extruded to a thin slab at its position and orientation along the path.
    /// - Each section colored with a distinct color from a rotating palette.
    /// - Sections are placed in a separate visual part named "Visualized Loft Layers".
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts the thickness of each section slab.
    ///
    func visualized() -> any Geometry3D {
        LoftVisualization(path: path, sections: sections, reference: reference, target: target)
    }
}

fileprivate struct LoftVisualization: Shape3D {
    let path: OpaqueParametricCurve<Vector3D>
    let sections: [Loft.Section]
    let reference: Direction2D
    let target: ReferenceTarget

    var body: any Geometry3D {
        @Environment var environment
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        let thickness = 0.001 * scale

        let frames = path.curve.frames(environment: environment, target: target, targetReference: reference, perpendicularBounds: nil)

        Union {
            for (index, section) in sections.enumerated() {
                let transform = frames.binarySearchInterpolate(target: section.distance, key: \.distance, result: \.transform)
                section.geometry()
                    .extruded(height: thickness)
                    .translated(z: -thickness / 2)
                    .transformed(transform)
                    .colored(Color.layerColors[index % Color.layerColors.count], alpha: 0.7)
            }
        }
        .inPart(.visualizedLoftLayers)
    }
}

fileprivate extension Color {
    static let layerColors: [Color] = [.red, .blue, .green, .orange, .purple, .cyan, .magenta, .yellow]
}
