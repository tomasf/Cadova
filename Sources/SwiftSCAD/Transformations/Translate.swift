import Foundation

fileprivate struct Translate<V: Vector> where V: SCADValue {
    let body: V.Geometry
    let distance: V

    let moduleName = "translate"
    var moduleParameters: CodeFragment.Parameters {
        ["v": distance]
    }
    var bodyTransform: V.Transform { .translation(distance) }
}

extension Translate<Vector2D>: Geometry2D, TransformedGeometry2D {}
extension Translate<Vector3D>: Geometry3D, TransformedGeometry3D {}

public extension Geometry2D {
    /// Translate geometry in 2D space.
    ///
    /// This method moves the geometry by a specified distance in the 2D space. The distance is represented as a vector where each component indicates the movement along the corresponding axis.
    ///
    /// - Parameters:
    ///   - distance: A `Vector2D` representing the distance to move along the x and y axes.
    /// - Returns: A translated geometry.
    func translated(_ distance: Vector2D) -> any Geometry2D {
        Translate(body: self, distance: distance)
    }

    /// Translate geometry in 2D space using individual components.
    ///
    /// This method moves the geometry by specifying the individual distance components along the x and y axes. It allows for precise control over the translation in each direction.
    ///
    /// - Parameters:
    ///   - x: The distance to move along the x-axis.
    ///   - y: The distance to move along the y-axis.
    /// - Returns: A translated geometry.
    func translated(x: Double = 0, y: Double = 0) -> any Geometry2D {
        translated([x, y])
    }
}

public extension Geometry3D {
    /// Translate geometry in 3D space.
    ///
    /// This method moves the geometry by a specified distance in the 3D space. The distance is represented as a vector where each component indicates the movement along the corresponding axis.
    ///
    /// - Parameters:
    ///   - distance: A `Vector3D` representing the distance to move along the x, y, and z axes.
    /// - Returns: A translated geometry.
    func translated(_ distance: Vector3D) -> any Geometry3D {
        Translate(body: self, distance: distance)
    }

    /// Translate geometry in 3D space using a 2D vector for the x and y axes and an individual z-axis component.
    ///
    /// This method allows specifying a 2D vector for the x and y components and an individual value for the z-axis, providing flexibility when working with combined 2D and 3D coordinates.
    ///
    /// - Parameters:
    ///   - xyDistance: A `Vector2D` representing the distance to move along the x and y axes.
    ///   - z: The distance to move along the z-axis.
    /// - Returns: A translated geometry.
    /// 
    func translated(_ xyDistance: Vector2D, z: Double) -> any Geometry3D {
        translated(.init(xyDistance, z: z))
    }

    /// Translate geometry in 3D space using individual components.
    ///
    /// This method moves the geometry by specifying the individual distance components along the x, y, and z axes. It allows for precise control over the translation in each direction.
    ///
    /// - Parameters:
    ///   - x: The distance to move along the x-axis.
    ///   - y: The distance to move along the y-axis.
    ///   - z: The distance to move along the z-axis.
    /// - Returns: A translated geometry.
    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> any Geometry3D {
        translated([x, y, z])
    }
}
