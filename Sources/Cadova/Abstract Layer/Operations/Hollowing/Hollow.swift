import Foundation

public extension Geometry3D {
    /// Hollows the geometry out, leaving a closed shell with walls of the given thickness.
    ///
    /// The cavity is the geometry offset inward by the wall thickness, so the walls are uniformly thick everywhere,
    /// following the outside's shape. Parts thinner than twice the wall thickness stay solid.
    ///
    /// - Parameter wallThickness: The thickness of the walls.
    /// - Returns: The hollowed geometry.
    ///
    /// - SeeAlso: ``offset(amount:)``
    ///
    func hollowed(wallThickness: Double) -> any Geometry3D {
        subtracting {
            offset(amount: -wallThickness)
        }
    }

    /// Hollows the geometry out, providing both the original and hollowed geometries to a builder closure.
    ///
    /// This enables further composition, such as combining the two or constructing additional geometry based on
    /// their relationship.
    ///
    /// - Parameters:
    ///   - wallThickness: The thickness of the walls.
    ///   - reader: A closure that receives both the original geometry and the hollowed geometry, and returns a new
    ///     composed geometry.
    /// - Returns: The result of the builder closure.
    ///
    /// - SeeAlso: ``hollowed(wallThickness:)``
    ///
    func hollowed<Output: Dimensionality>(
        wallThickness: Double,
        @GeometryBuilder<Output> reader: @escaping @Sendable (_ original: any Geometry3D, _ hollowed: any Geometry3D) -> Output.Geometry
    ) -> Output.Geometry {
        reader(self, hollowed(wallThickness: wallThickness))
    }
}
