import Foundation

public extension Environment {
    private static let key = Environment.ValueKey(rawValue: "SwiftSCAD.Operation")

    enum Operation {
        case addition
        case subtraction

        static prefix func !(_ op: Operation) -> Operation {
            op == .addition ? .subtraction : .addition
        }
    }

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
