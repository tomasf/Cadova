import Foundation

/// A rectangular cuboid shape
public struct Box: CoreGeometry3D {
    let size: Vector3D
    let center: Axes3D

    /// Initializes a new box with specific dimensions and centering options.
    /// - Parameters:
    ///   - size: A `Vector3D` value indicating the size of the box. Each component of the vector represents the length of the box along the corresponding axis.
    ///   - center: An `Axes3D` option set indicating which axes should be centered around the origin. By omitting or passing an empty set, the box's corner aligns with the origin. Specifying axes centers the box along those axes.
    ///
    /// Example usage:
    /// ```
    /// let box = Box([10, 20, 30], center: .xy)
    /// ```
    /// This creates a box of size 10x20x30, centered along the X and Y axes but not the Z axis.
    public init(_ size: Vector3D, center: Axes3D = []) {
        self.size = size
        self.center = center
    }

    func call(in environment: Environment) -> SCADCall {
        let cube = SCADCall(
            name: "cube",
            params: ["size": size],
            body: nil
        )

        guard !center.isEmpty else {
            return cube
        }

        return SCADCall(
            name: "translate",
            params: ["v": (size / -2).setting(axes: center.inverted, to: 0)],
            body: cube
        )
    }
}
