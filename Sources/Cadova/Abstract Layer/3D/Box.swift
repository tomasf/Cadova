import Foundation

/// A rectangular cuboid shape.
public struct Box: Geometry {
    /// The dimensions of the box along each axis.
    public let size: Vector3D

    /// Initializes a new box with specific dimensions and centering options.
    /// - Parameters:
    ///   - size: A `Vector3D` value indicating the size of the box. Each component of the vector represents the length of the box along the corresponding axis.
    ///
    /// Example usage:
    /// ```
    /// let box = Box([10, 20, 30])
    /// ```
    /// This creates a box of size 10x20x30.
    ///
    public init(_ size: Vector3D) {
        self.size = size
    }

    /// Creates a new `Box` instance with the specified size.
    ///
    /// - Parameters:
    ///   - x: The size of the box in the X axis
    ///   - y: The size of the box in the Y axis
    ///   - z: The size of the box in the Z axis
    ///
    public init(x: Double, y: Double, z: Double) {
        self.init([x, y, z])
    }

    /// Initializes a box with equal dimensions along all axes.
    /// - Parameters:
    ///   - side: A `Double` value indicating the length of each side of the cube.
    ///
    /// Example usage:
    /// ```
    /// let cube = Box(10)
    /// ```
    /// This creates a cube of size 10x10x10.
    ///
    public init(_ side: Double) {
        self.size = [side, side, side]
    }

    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D3.BuildResult {
        .init(.shape(.box(size: size)))
    }
}

public extension Box {
    /// The volume of the box.
    var volume: Double {
        size.x * size.y * size.z
    }

    /// The surface area of the box.
    var surfaceArea: Double {
        2 * (size.x * size.y + size.x * size.z + size.y * size.z)
    }

    /// The length of the space diagonal of the box.
    var diagonal: Double {
        (size.x * size.x + size.y * size.y + size.z * size.z).squareRoot()
    }

    /// The average edge length of the box.
    var averageEdgeLength: Double {
        (size.x + size.y + size.z) / 3
    }
}
