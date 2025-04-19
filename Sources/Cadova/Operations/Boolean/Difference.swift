import Foundation
import Manifold3D

fileprivate struct Difference<D: Dimensionality>: GeometryContainer {
    let positive: D.Geometry
    let negative: D.Geometry

    public var body: D.Geometry {
        BooleanGeometry(children: [positive, negative.invertingOperation()], type: .difference)
    }
}

public extension Geometry {
    /// Subtract other geometry from this geometry
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .subtracting {
    ///        Circle(diameter: 4)
    ///     }
    /// ```
    /// ```swift
    /// Box([10, 10, 5])
    ///     .subtracting {
    ///        Cylinder(diameter: 4, height: 3)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - negative: The negative geometry to subtract
    /// - Returns: The new geometry

    func subtracting(@GeometryBuilder<D> _ negative: () -> D.Geometry) -> D.Geometry {
        Difference(positive: self, negative: negative())
    }

    func subtracting(_ negative: (D.Geometry)?...) -> D.Geometry {
        Difference(positive: self, negative: Union(negative))
    }
}
