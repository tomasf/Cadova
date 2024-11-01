import Foundation

// Remove underscore once deprecated EnvironmentReader is removed
struct _EnvironmentReader<Geometry> {
    let body: (Environment) -> Geometry
}

extension _EnvironmentReader<any Geometry2D>: Geometry2D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        body(environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Boundary2D {
        body(environment).boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(environment).elements(in: environment)
    }
}

extension _EnvironmentReader<any Geometry3D>: Geometry3D {
    func codeFragment(in environment: Environment) -> CodeFragment {
        body(environment).codeFragment(in: environment)
    }

    func boundary(in environment: Environment) -> Boundary3D {
        body(environment).boundary(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(environment).elements(in: environment)
    }
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
///
/// - Parameter body: A closure that takes the current `Environment` and returns a new `Geometry2D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func readEnvironment(@GeometryBuilder2D _ body: @escaping (Environment) -> any Geometry2D) -> any Geometry2D {
    _EnvironmentReader(body: body)
}

public func readEnvironment<T>(
    _ keyPath1: KeyPath<Environment, T>,
    @GeometryBuilder2D _ body: @escaping (T) -> any Geometry2D
) -> any Geometry2D {
    readEnvironment {
        body($0[keyPath: keyPath1])
    }
}

public func readEnvironment<T, U>(
    _ keyPath1: KeyPath<Environment, T>,
    _ keyPath2: KeyPath<Environment, U>,
    @GeometryBuilder2D _ body: @escaping (T, U) -> any Geometry2D
) -> any Geometry2D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2])
    }
}

public func readEnvironment<T, U, V>(
    _ keyPath1: KeyPath<Environment, T>,
    _ keyPath2: KeyPath<Environment, U>,
    _ keyPath3: KeyPath<Environment, V>,
    @GeometryBuilder2D _ body: @escaping (T, U, V) -> any Geometry2D
) -> any Geometry2D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2], $0[keyPath: keyPath3])
    }
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
///
/// - Parameter body: A closure that takes the current `Environment` and returns a new `Geometry3D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func readEnvironment(@GeometryBuilder3D _ body: @escaping (Environment) -> any Geometry3D) -> any Geometry3D {
    _EnvironmentReader(body: body)
}

public func readEnvironment<T>(
    _ keyPath1: KeyPath<Environment, T>,
    @GeometryBuilder3D _ body: @escaping (T) -> any Geometry3D
) -> any Geometry3D {
    readEnvironment {
        body($0[keyPath: keyPath1])
    }
}

public func readEnvironment<T, U>(
    _ keyPath1: KeyPath<Environment, T>,
    _ keyPath2: KeyPath<Environment, U>,
    @GeometryBuilder3D _ body: @escaping (T, U) -> any Geometry3D
) -> any Geometry3D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2])
    }
}

public func readEnvironment<T, U, V>(
    _ keyPath1: KeyPath<Environment, T>,
    _ keyPath2: KeyPath<Environment, U>,
    _ keyPath3: KeyPath<Environment, V>,
    @GeometryBuilder3D _ body: @escaping (T, U, V) -> any Geometry3D
) -> any Geometry3D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2], $0[keyPath: keyPath3])
    }
}
