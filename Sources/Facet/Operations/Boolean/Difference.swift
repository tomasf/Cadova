import Foundation

fileprivate struct Difference<V: Vector> {
    private let positive: V.Geometry
    private let negative: V.Geometry

    var children: [V.Geometry] { [positive, negative] }
    let moduleName = "difference"
    let boundaryMergeStrategy = Boundary<V>.MergeStrategy.first
    let combination = GeometryCombination.difference
}

extension Difference<Vector2D>: Geometry2D, CombinedGeometry2D {
    init(positive: V.Geometry, negative: V.Geometry) {
        self.positive = positive
        self.negative = negative
            .invertingOperation()
    }
}

extension Difference<Vector3D>: Geometry3D, CombinedGeometry3D {
    init(positive: V.Geometry, negative: V.Geometry) {
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
