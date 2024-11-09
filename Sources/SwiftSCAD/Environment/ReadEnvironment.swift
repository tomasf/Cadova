import Foundation

struct EnvironmentReader<Geometry> {
    let body: (EnvironmentValues) -> Geometry
}

extension EnvironmentReader<any Geometry2D>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        body(environment).evaluated(in: environment)
    }
}

extension EnvironmentReader<any Geometry3D>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        body(environment).evaluated(in: environment)
    }
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
///
/// - Parameter body: A closure that takes the current `EnvironmentValues` and returns a new `Geometry2D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func readEnvironment(@GeometryBuilder2D _ body: @escaping (EnvironmentValues) -> any Geometry2D) -> any Geometry2D {
    EnvironmentReader(body: body)
}

public func readEnvironment<T>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    @GeometryBuilder2D _ body: @escaping (T) -> any Geometry2D
) -> any Geometry2D {
    readEnvironment {
        body($0[keyPath: keyPath1])
    }
}

public func readEnvironment<T, U>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    _ keyPath2: KeyPath<EnvironmentValues, U>,
    @GeometryBuilder2D _ body: @escaping (T, U) -> any Geometry2D
) -> any Geometry2D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2])
    }
}

public func readEnvironment<T, U, V>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    _ keyPath2: KeyPath<EnvironmentValues, U>,
    _ keyPath3: KeyPath<EnvironmentValues, V>,
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
/// - Parameter body: A closure that takes the current `EnvironmentValues` and returns a new `Geometry3D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func readEnvironment(@GeometryBuilder3D _ body: @escaping (EnvironmentValues) -> any Geometry3D) -> any Geometry3D {
    EnvironmentReader(body: body)
}

public func readEnvironment<T>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    @GeometryBuilder3D _ body: @escaping (T) -> any Geometry3D
) -> any Geometry3D {
    readEnvironment {
        body($0[keyPath: keyPath1])
    }
}

public func readEnvironment<T, U>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    _ keyPath2: KeyPath<EnvironmentValues, U>,
    @GeometryBuilder3D _ body: @escaping (T, U) -> any Geometry3D
) -> any Geometry3D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2])
    }
}

public func readEnvironment<T, U, V>(
    _ keyPath1: KeyPath<EnvironmentValues, T>,
    _ keyPath2: KeyPath<EnvironmentValues, U>,
    _ keyPath3: KeyPath<EnvironmentValues, V>,
    @GeometryBuilder3D _ body: @escaping (T, U, V) -> any Geometry3D
) -> any Geometry3D {
    readEnvironment {
        body($0[keyPath: keyPath1], $0[keyPath: keyPath2], $0[keyPath: keyPath3])
    }
}
