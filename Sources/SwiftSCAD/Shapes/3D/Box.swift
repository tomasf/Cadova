import Foundation

/// A rectangular cuboid shape
public struct Box: Geometry3D {
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

    /// Creates a new `Box` instance with the specified size.
    ///
    /// - Parameters:
    ///   - x: The size of the box in the X axis
    ///   - y: The size of the box in the Y axis
    ///   - z: The size of the box in the Z axis
    public init(x: Double, y: Double, z: Double) {
        self.init([x, y, z])
    }

    /// Initializes a box with equal dimensions along all axes.
    /// - Parameters:
    ///   - side: A `Double` value indicating the length of each side of the cube.
    ///   - center: An `Axes3D` option set indicating which axes should be centered around the origin. By omitting or passing an empty set, the cube's corner aligns with the origin. Specifying axes centers the cube along those axes.
    ///
    /// Example usage:
    /// ```
    /// let cube = Box(10, center: .xy)
    /// ```
    /// This creates a cube of size 10x10x10, centered along the X and Y axes but not the Z axis.
    public init(_ side: Double, center: Axes3D = []) {
        self.size = [side, side, side]
        self.center = center
    }

    public func output(in environment: Environment) -> GeometryOutput3D {
        if center.isEmpty {
            .init(
                invocation: .init(name: "cube", parameters: ["size": size]),
                boundary: .box(size)
            )
        } else {
            Box(size)
                .translated((size / -2).with(center.inverted, as: 0))
                .output(in: environment)
        }
    }
}
