import Foundation

internal struct Empty2D: Geometry2D {
    func output(in environment: Environment) -> GeometryOutput2D {
        .emptyLeaf
    }
}

internal struct Empty3D: Geometry3D {
    func output(in environment: Environment) -> GeometryOutput3D {
        .emptyLeaf
    }
}
