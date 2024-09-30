import Foundation

struct Fill: WrappedGeometry2D {
    let body: any Geometry2D
    let invocationName: String? = "fill"
}

public extension Geometry2D {
    /// Fill a 2D geometry
    ///
    /// This operation applies a filling operation to the current geometry, removing internal holes without altering the external outline.
    ///
    /// - Returns: A new geometry representing the shape with its holes filled.
    func filled() -> any Geometry2D {
        Fill(body: self)
    }
}
