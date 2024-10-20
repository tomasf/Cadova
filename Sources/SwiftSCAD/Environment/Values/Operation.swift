import Foundation

public extension Environment {
    private static let key = ValueKey("SwiftSCAD.Operation")

    /// Represents a geometric operation, specifically for determining if geometries are being added or subtracted.
    enum Operation: Sendable {
        /// Represents the addition of geometries.
        case addition
        /// Represents the subtraction of geometries, typically used for creating holes or negative spaces within another geometry.
        case subtraction

        /// Toggles the operation between addition and subtraction.
        ///
        /// Applying this operator to an operation inverts it: if it's `.addition`, it becomes `.subtraction`, and vice versa.
        static prefix func !(_ op: Operation) -> Operation {
            op == .addition ? .subtraction : .addition
        }
    }

    /// Accesses the current operation state from the environment, determining if a geometry is being added to or subtracted from a composite structure.
    ///
    /// This property allows for dynamic adjustments based on a geometry's intended role (additive or subtractive).
    var operation: Operation {
        self[Self.key] as? Operation ?? .addition
    }

    internal func invertingOperation() -> Environment {
        setting(key: Self.key, value: !operation)
    }
}

internal extension Geometry2D {
    func invertingOperation() -> any Geometry2D {
        withEnvironment { environment in
            environment.invertingOperation()
        }
    }
}

internal extension Geometry3D {
    func invertingOperation() -> any Geometry3D {
        withEnvironment { environment in
            environment.invertingOperation()
        }
    }
}

public func readOperation(@UnionBuilder2D _ reader: @escaping (Environment.Operation) -> any Geometry2D) -> any Geometry2D {
    readEnvironment { e in
        reader(e.operation)
    }
}

public func readOperation(@UnionBuilder3D _ reader: @escaping (Environment.Operation) -> any Geometry3D) -> any Geometry3D {
    readEnvironment { e in
        reader(e.operation)
    }
}
