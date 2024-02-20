import Foundation

private extension Environment {
    static let key = Environment.ValueKey(rawValue: "SwiftSCAD.Tolerance")

    func settingTolerance(_ tolerance: Double) -> Environment {
        setting(key: Self.key, value: tolerance)
    }
}

public extension Environment {
    var tolerance: Double {
        self[Self.key] as? Double ?? 0
    }
}

public extension Geometry3D {
    func withTolerance(_ tolerance: Double) -> any Geometry3D {
        withEnvironment { enviroment in
            enviroment.settingTolerance(tolerance)
        }
    }
}

public extension Geometry2D {
    func withTolerance(_ tolerance: Double) -> any Geometry2D {
        withEnvironment { enviroment in
            enviroment.settingTolerance(tolerance)
        }
    }
}
