import Foundation

internal struct EnvironmentReader2D: Geometry2D {
    let body: (Environment) -> any Geometry2D

    func invocation(in environment: Environment) -> Invocation {
        body(environment).invocation(in: environment)
    }
    
    func boundary(in environment: Environment) -> Bounds {
        body(environment).boundary(in: environment)
    }
    
    func anchors(in environment: Environment) -> [Anchor : AffineTransform3D] {
        body(environment).anchors(in: environment)
    }
    
    func elements(in environment: Environment) -> [ObjectIdentifier : any ResultElement] {
        body(environment).elements(in: environment)
    }
}

internal struct EnvironmentReader3D: Geometry3D {
    let body: (Environment) -> any Geometry3D

    func invocation(in environment: Environment) -> Invocation {
        body(environment).invocation(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(environment).boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor : AffineTransform3D] {
        body(environment).anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier : any ResultElement] {
        body(environment).elements(in: environment)
    }
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
///
/// - Parameter body: A closure that takes the current `Environment` and returns a new `Geometry2D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func EnvironmentReader(@UnionBuilder2D body: @escaping (Environment) -> any Geometry2D) -> any Geometry2D {
    EnvironmentReader2D(body: body)
}

/// Creates a geometry that can read and respond to the current environment settings.
///
/// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
///
/// - Parameter body: A closure that takes the current `Environment` and returns a new `Geometry3D` instance based on that environment.
/// - Returns: A geometry instance that can be dynamically created based on the current environment.
public func EnvironmentReader(@UnionBuilder3D body: @escaping (Environment) -> any Geometry3D) -> any Geometry3D {
    EnvironmentReader3D(body: body)
}

public extension Geometry2D {
    /// Creates a geometry that can read and respond to the current environment settings.
    ///
    /// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
    ///
    /// - Parameter body: A closure that takes the wrapped geometry and the current `Environment` and returns a new `Geometry2D` instance based on that environment.
    /// - Returns: A geometry instance that can be dynamically created based on the current environment.
    func readingEnvironment(@UnionBuilder2D _ body: @escaping (any Geometry2D, Environment) -> any Geometry2D) -> any Geometry2D {
        EnvironmentReader2D { environment in
            body(self, environment)
        }
    }
}

public extension Geometry3D {
    /// Creates a geometry that can read and respond to the current environment settings.
    ///
    /// Use this function to create a geometry that has access to environmental information. This allows for dynamic and conditional geometry creation based on the current environment settings such as facets, text settings, or custom values you've defined.
    ///
    /// - Parameter body: A closure that takes the wrapped geometry and the current `Environment` and returns a new `Geometry3D` instance based on that environment.
    /// - Returns: A geometry instance that can be dynamically created based on the current environment.
    func readingEnvironment(@UnionBuilder3D _ body: @escaping (any Geometry3D, Environment) -> any Geometry3D) -> any Geometry3D {
        EnvironmentReader3D { environment in
            body(self, environment)
        }
    }
}
