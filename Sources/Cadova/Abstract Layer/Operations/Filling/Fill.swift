import Foundation

public extension Geometry2D {
    /// Fill a 2D geometry
    ///
    /// This operation applies a filling operation to the current geometry, removing internal holes without altering
    /// the external outline.
    ///
    /// - Returns: A new geometry representing the shape with its holes filled.
    func fillingHoles() -> any Geometry2D {
        CachedConcreteTransformer(body: self, name: "Cadova.Fill") {
            .boolean(.union, with: $0.polygons().map {
                D2.Concrete(polygons: [$0], fillRule: .nonZero)
            })
        }
    }
}

