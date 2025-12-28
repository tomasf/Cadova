import Foundation

fileprivate struct DirectionVisualization: Shape3D {
    let direction: Direction3D

    var body: any Geometry3D {
        @Environment(\.visualizationOptions.scale) var scale = 1.0
        @Environment(\.visualizationOptions.primaryColor) var color = .red

        Stack(.z) {
            Cylinder(diameter: 0.5, height: 8)
            Cylinder(bottomDiameter: 2, topDiameter: 0, height: 2)
        }
        .scaled(scale)
        .rotated(from: .up, to: direction)
        .withSegmentation(count: 8)
        .colored(color)
        .inPart(.visualizedDirection)
    }
}

public extension Direction {
    /// Generates a 3D arrow visualization representing this direction.
    ///
    /// The arrow’s base is aligned with the origin and points toward the direction. The
    /// visualization’s scale and color respond to the environment values (`withVisualizationScale(_:)`
    /// and `withVisualizationColor(_:)`). This is intended for debugging or visual inspection of
    /// directional data.
    ///
    /// - Returns: A 3D geometry visualizing the direction as an arrow.
    func visualized() -> any Geometry3D {
        DirectionVisualization(direction: Direction3D(unitVector.vector3D))
    }
}
