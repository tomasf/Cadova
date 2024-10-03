import Foundation

struct Difference2D: CombinedGeometry2D {
    let positive: any Geometry2D
    let negative: any Geometry2D

    init(positive: any Geometry2D, negative: any Geometry2D) {
        self.positive = positive
        self.negative = negative
            .invertingOperation()
    }

    var children: [any Geometry2D] { [positive, negative] }
    let moduleName = "difference"
    let boundaryMergeStrategy = Boundary2D.MergeStrategy.first
    let combination = GeometryCombination.difference
}

struct Difference3D: CombinedGeometry3D {
    let positive: any Geometry3D
    let negative: any Geometry3D

    init(positive: any Geometry3D, negative: any Geometry3D) {
        self.positive = positive
        self.negative = negative
            .invertingOperation()
    }

    var children: [any Geometry3D] { [positive, negative] }
    let moduleName = "difference"
    let boundaryMergeStrategy = Boundary3D.MergeStrategy.first
    let combination = GeometryCombination.difference
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

    func subtracting(@UnionBuilder2D _ negative: () -> any Geometry2D) -> any Geometry2D {
        Difference2D(positive: self, negative: negative())
    }

    func subtracting(_ negative: (any Geometry2D)?...) -> any Geometry2D {
        Difference2D(positive: self, negative: Union(negative))
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

    func subtracting(@UnionBuilder3D _ negative: () -> any Geometry3D) -> any Geometry3D {
        Difference3D(positive: self, negative: negative())
    }

    func subtracting(_ negative: (any Geometry3D)?...) -> any Geometry3D {
        Difference3D(positive: self, negative: Union(negative))
    }
}
