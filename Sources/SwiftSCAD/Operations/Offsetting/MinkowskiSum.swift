import Foundation

struct Minkowski2D: Geometry2D {
    let children: [any Geometry2D]

    func output(in environment: Environment) -> Output {
        .init(
            invocation: .init(name: "minkowski"),
            body: children,
            environment: environment,
            boundaryMergeStrategy: .minkowskiSum,
            combination: .minkowskiSum
        )
    }
}

struct Minkowski3D: Geometry3D {
    let children: [any Geometry3D]

    func output(in environment: Environment) -> Output {
        .init(
            invocation: .init(name: "minkowski"),
            body: children,
            environment: environment,
            boundaryMergeStrategy: .minkowskiSum,
            combination: .minkowskiSum
        )
    }
}

public extension Geometry2D {
    /// Combines the current geometry with one or more other geometries using the Minkowski sum operation.
    ///
    /// The Minkowski sum operation creates a new geometry that represents the combination of this geometry with each of the geometries provided by the `adding` closure. This operation is akin to blending the spatial features of the geometries, where the resulting shape embodies the outline that would be traced by moving one shape around the perimeter of the other.
    ///
    /// - Parameter adding: The 3D geometries to combine with this geometry.
    /// - Returns: A geometry representing the Minkowski sum
    func minkowskiSum(@SequenceBuilder2D adding other: () -> [any Geometry2D]) -> any Geometry2D {
        Minkowski2D(children: [self] + other())
    }
}

public extension Geometry3D {
    /// Combines the current geometry with one or more other geometries using the Minkowski sum operation.
    ///
    /// The Minkowski sum operation creates a new geometry that represents the combination of this geometry with each of the geometries provided by the `adding` closure. This operation is akin to blending the spatial features of the geometries, where the resulting shape embodies the outline that would be traced by moving one shape around the perimeter of the other.
    ///
    /// - Parameter adding: The 3D geometries to combine with this geometry.
    /// - Returns: A geometry representing the Minkowski sum
    func minkowskiSum(@SequenceBuilder3D adding other: () -> [any Geometry3D]) -> any Geometry3D {
        Minkowski3D(children: [self] + other())
    }
}
