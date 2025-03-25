import Foundation
import Manifold3D

fileprivate struct Difference<D: Dimensionality> {
    private let positive: D.Geometry
    private let negative: D.Geometry

    var children: [D.Geometry] { [positive, negative] }
    let combination = GeometryCombination.difference

    func combine(_ children: [D.Primitive], in environment: EnvironmentValues) -> D.Primitive {
        .boolean(.difference, with: children)
    }
}

extension Difference<D2>: Geometry2D, CombinedGeometry2D {
    init(positive: D.Geometry, negative: D.Geometry) {
        self.positive = positive
        self.negative = negative
            .invertingOperation()
    }
}

extension Difference<D3>: Geometry3D, CombinedGeometry3D {
    init(positive: D.Geometry, negative: D.Geometry) {
        self.positive = positive
        self.negative = negative
            .invertingOperation()
    }
}


public extension Geometry2D {
    /// Subtract other geometry from this geometry
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .subtracting {
    ///        Circle(diameter: 4)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - negative: The negative geometry to subtract
    /// - Returns: The new geometry

    func subtracting(@GeometryBuilder2D _ negative: () -> any Geometry2D) -> any Geometry2D {
        Difference(positive: self, negative: negative())
    }

    func subtracting(_ negative: (any Geometry2D)?...) -> any Geometry2D {
        Difference(positive: self, negative: Union(negative))
    }
}

public extension Geometry3D {
    /// Subtract other geometry from this geometry
    ///
    /// ## Example
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

    func subtracting(@GeometryBuilder3D _ negative: () -> any Geometry3D) -> any Geometry3D {
        Difference(positive: self, negative: negative())
    }

    func subtracting(_ negative: (any Geometry3D)?...) -> any Geometry3D {
        Difference(positive: self, negative: Union(negative))
    }
}
