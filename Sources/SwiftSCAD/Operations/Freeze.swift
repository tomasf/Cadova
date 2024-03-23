import Foundation

internal extension Environment {
    static private var environmentKey: Environment.ValueKey = .init(rawValue: "SwiftSCAD.FreezeContext")

    class FreezeContext {
        var frozenGeometryOutput: [AnyHashable: Any] = [:]

        subscript<T>(_ key: AnyHashable) -> T? {
            get { frozenGeometryOutput[key] as? T }
            set { frozenGeometryOutput[key] = newValue }
        }
    }

    var freezeContext: FreezeContext? {
        self[Self.environmentKey] as? FreezeContext
    }

    func addingFreezeContext() -> Environment {
        setting(key: Self.environmentKey, value: FreezeContext())
    }
}

struct FrozenGeometry2D: Geometry2D {
    let body: any Geometry2D
    let key: AnyHashable

    func output(in environment: Environment) -> Output {
        if let output = environment.freezeContext?[key] as Output? {
            return output
        } else {
            let output = body.output(in: environment)
            environment.freezeContext?[key] = output
            return output
        }
    }
}

struct FrozenGeometry3D: Geometry3D {
    let body: any Geometry3D
    let key: AnyHashable

    func output(in environment: Environment) -> Output {
        if let output = environment.freezeContext?[key] as Output? {
            return output
        } else {
            let output = body.output(in: environment)
            environment.freezeContext?[key] = output
            return output
        }
    }
}

public extension Geometry2D {
    func frozen<K: Hashable>(as key: K) -> any Geometry2D {
        FrozenGeometry2D(body: self, key: key)
    }

    func frozen(_ file: String = #file, _ line: Int = #line) -> any Geometry2D {
        FrozenGeometry2D(body: self, key: "\(file):\(line)")
    }
}

public extension Geometry3D {
    func frozen<K: Hashable>(as key: K) -> any Geometry3D {
        FrozenGeometry3D(body: self, key: key)
    }

    func frozen(_ file: String = #file, _ line: Int = #line) -> any Geometry3D {
        FrozenGeometry3D(body: self, key: "\(file):\(line)")
    }
}
