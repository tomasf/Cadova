import Foundation

public extension EnvironmentValues {
    private static let key = Key("Cadova.Operation")

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

    internal func withOperation(_ value: Operation) -> EnvironmentValues {
        setting(key: Self.key, value: value)
    }

    internal func invertingOperation() -> EnvironmentValues {
        withOperation(!operation)
    }
}

internal extension Geometry {
    func invertingOperation() -> D.Geometry {
        withEnvironment { environment in
            environment.invertingOperation()
        }
    }
}

public func readOperation(@GeometryBuilder2D _ reader: @Sendable @escaping (EnvironmentValues.Operation) -> any Geometry2D) -> any Geometry2D {
    readEnvironment { e in
        reader(e.operation)
    }
}

public func readOperation(@GeometryBuilder3D _ reader: @Sendable @escaping (EnvironmentValues.Operation) -> any Geometry3D) -> any Geometry3D {
    readEnvironment { e in
        reader(e.operation)
    }
}
