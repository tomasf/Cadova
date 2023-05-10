import Foundation

public struct Environment {
    private let values: [ValueKey: Any]

    public init() {
        self.init(values: [:])
    }

    init(values: [ValueKey: Any]) {
        self.values = values
	}

    public func setting(_ newValues: [ValueKey: Any]) -> Environment {
        Environment(values: values.merging(newValues, uniquingKeysWith: { $1 }))
    }

    public func setting(key: ValueKey, value: Any?) -> Environment {
        var values = self.values
        values[key] = value
        return Environment(values: values)
    }

    subscript(key: ValueKey) -> Any? {
        values[key]
    }
}

public extension Environment {
    struct ValueKey: RawRepresentable, Hashable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

internal struct EnvironmentReader2D: Geometry2D {
	let body: (Environment) -> Geometry2D

	func scadString(in environment: Environment) -> String {
		body(environment).scadString(in: environment)
	}
}

internal struct EnvironmentReader3D: Geometry3D {
	let body: (Environment) -> Geometry3D

	func scadString(in environment: Environment) -> String {
		body(environment).scadString(in: environment)
	}
}

internal func EnvironmentReader(@UnionBuilder body: @escaping (Environment) -> Geometry2D) -> Geometry2D {
    EnvironmentReader2D(body: body)
}

internal func EnvironmentReader(@UnionBuilder body: @escaping (Environment) -> Geometry3D) -> Geometry3D {
    EnvironmentReader3D(body: body)
}

struct EnvironmentModifier2D: Geometry2D {
    let body: Geometry2D
    let modification: (Environment) -> Environment

    func scadString(in environment: Environment) -> String {
        body.scadString(in: modification(environment))
    }
}

struct EnvironmentModifier3D: Geometry3D {
    let body: Geometry3D
    let modification: (Environment) -> Environment

    func scadString(in environment: Environment) -> String {
        body.scadString(in: modification(environment))
    }
}

public extension Geometry2D {
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> Geometry2D {
        EnvironmentModifier2D(body: self, modification: modifier)
    }

    func readingEnvironment(@UnionBuilder _ body: @escaping (Environment) -> Geometry2D) -> Geometry2D {
        EnvironmentReader2D(body: body)
    }
}

public extension Geometry3D {
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> Geometry3D {
        EnvironmentModifier3D(body: self, modification: modifier)
    }

    func readingEnvironment(@UnionBuilder _ body: @escaping (Environment) -> Geometry3D) -> Geometry3D {
        EnvironmentReader3D(body: body)
    }
}
