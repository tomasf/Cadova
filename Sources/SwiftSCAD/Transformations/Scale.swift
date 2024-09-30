import Foundation

struct Scale2D: TransformedGeometry2D {
    let body: any Geometry2D
    let scale: Vector2D

    let invocationName = "scale"
    var invocationParameters: Invocation.Parameters {
        ["v": scale]
    }
    var bodyTransform: AffineTransform2D { .scaling(scale) }
}

struct Scale3D: TransformedGeometry3D {
    let body: any Geometry3D
    let scale: Vector3D

    let invocationName = "scale"
    var invocationParameters: Invocation.Parameters {
        ["v": scale]
    }
    var bodyTransform: AffineTransform3D { .scaling(scale) }
}

public extension Geometry2D {
    /// Scale geometry uniformly or non-uniformly.
    ///
    /// This method allows scaling the geometry by a specified vector, where each component of the vector represents the scaling factor along the corresponding axis.
    ///
    /// - Parameters:
    ///   - scale: A `Vector2D` representing the scaling factors along the x and y axes.
    /// - Returns: A scaled geometry.
    func scaled(_ scale: Vector2D) -> any Geometry2D {
        Scale2D(body: self, scale: scale)
    }

    /// Scale geometry uniformly.
    ///
    /// This method scales the geometry uniformly across both axes using a single factor.
    ///
    /// - Parameters:
    ///   - factor: The uniform scaling factor.
    /// - Returns: A uniformly scaled geometry.
    func scaled(_ factor: Double) -> any Geometry2D {
        scaled(Vector2D(factor, factor))
    }

    /// Scale geometry non-uniformly.
    ///
    /// This method allows non-uniform scaling of the geometry by specifying individual scaling factors for the x and y axes.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    /// - Returns: A non-uniformly scaled geometry.
    func scaled(x: Double = 1, y: Double = 1) -> any Geometry2D {
        scaled(Vector2D(x, y))
    }

    /// Flip geometry along specified axes.
    ///
    /// This method flips the geometry along the axes specified. It can flip the geometry horizontally, vertically, or both.
    ///
    /// - Parameters:
    ///   - axes: The axes along which to flip the geometry.
    /// - Returns: A flipped geometry.
    func flipped(along axes: Axes2D) -> any Geometry2D {
        scaled(Vector2D(1, 1).with(axes, as: -1))
    }
}

public extension Geometry3D {
    /// Scale geometry uniformly or non-uniformly.
    ///
    /// This method allows scaling the geometry by a specified vector, where each component of the vector represents the scaling factor along the corresponding axis.
    ///
    /// - Parameters:
    ///   - scale: A `Vector3D` representing the scaling factors along the x, y, and z axes.
    /// - Returns: A scaled geometry.
    func scaled(_ scale: Vector3D) -> any Geometry3D {
        Scale3D(body: self, scale: scale)
    }

    /// Scale geometry uniformly.
    ///
    /// This method scales the geometry uniformly across all axes using a single factor.
    ///
    /// - Parameters:
    ///   - factor: The uniform scaling factor.
    /// - Returns: A uniformly scaled geometry.
    func scaled(_ factor: Double) -> any Geometry3D {
        scaled(Vector3D(factor, factor, factor))
    }

    /// Scale geometry non-uniformly.
    ///
    /// This method allows non-uniform scaling of the geometry by specifying individual scaling factors for the x, y, and z axes.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    /// - Returns: A non-uniformly scaled geometry.
    func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> any Geometry3D {
        scaled(Vector3D(x, y, z))
    }

    /// Flip geometry along specified axes.
    ///
    /// This method flips the geometry along the axes specified. It can flip the geometry along any combination of the x, y, and z axes.
    ///
    /// - Parameters:
    ///   - axes: The axes along which to flip the geometry.
    /// - Returns: A flipped geometry.
    func flipped(along axes: Axes3D) -> any Geometry3D {
        scaled(Vector3D(1, 1, 1).with(axes, as: -1))
    }
}
