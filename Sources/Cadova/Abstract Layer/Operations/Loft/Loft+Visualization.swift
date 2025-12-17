import Foundation

public extension Loft {
    /// Produces a visualization of the loft layers without performing the actual loft operation.
    ///
    /// Each layer is shown as a thin extruded shape at its Z position, with each layer
    /// colored distinctly to make it easy to identify individual layers. This is useful for
    /// debugging loft configurations and verifying that layers are positioned and shaped
    /// as expected before running the full loft operation.
    ///
    /// The visualization shows:
    /// - Each 2D layer shape extruded to a thin slab at its Z height.
    /// - Each layer colored with a distinct color from a rotating palette.
    /// - Layers are placed in a separate visual part named "Visualized Loft Layers".
    ///
    /// Configure appearance using the public Geometry modifiers:
    /// - `withVisualizationScale(_:)` adjusts the thickness of each layer slab.
    ///
    func visualized() -> any Geometry3D {
        LoftVisualization(layers: layers)
    }
}

fileprivate struct LoftVisualization: Shape3D {
    let layers: [Loft.Layer]

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        let thickness = 0.001 * scale

        Union {
            for (index, layer) in layers.enumerated() {
                layer.geometry()
                    .extruded(height: thickness)
                    .translated(z: layer.z - thickness / 2)
                    .colored(Color.layerColors[index % Color.layerColors.count], alpha: 0.7)
            }
        }
        .inPart(named: "Visualized Loft Layers", type: .visual)
    }
}

fileprivate extension Color {
    static let layerColors: [Color] = [.red, .blue, .green, .orange, .purple, .cyan, .magenta, .yellow]
}
