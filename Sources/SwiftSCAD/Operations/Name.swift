import Foundation

public enum TransformContext {
    case global
    case local

    fileprivate func prepare(_ geometry: any Geometry2D, in environment: Environment) -> any Geometry2D {
        switch self {
        case .global: geometry.transformed(.init(environment.transform))
        case .local: geometry
        }
    }

    fileprivate func prepare(_ geometry: any Geometry3D, in environment: Environment) -> any Geometry3D {
        switch self {
        case .global: geometry.transformed(environment.transform)
        case .local: geometry
        }
    }
}

public extension Geometry2D {
    func named(_ name: String, transform context: TransformContext = .global) -> any Geometry2D {
        EnvironmentReader { environment in
            modifyingResult(NamedGeometry.self) { oldValue in
                (oldValue ?? .init()).adding(context.prepare(self, in: environment), named: name)
            }
        }
    }

    func prefixingNames(_ prefix: String) -> any Geometry2D {
        modifyingResult(NamedGeometry.self) { namedGeometry in
            namedGeometry?.transformingNames { prefix + $0 }
        }
    }

    func suffixingNames(_ suffix: String) -> any Geometry2D {
        modifyingResult(NamedGeometry.self) { namedGeometry in
            namedGeometry?.transformingNames { $0 + suffix }
        }
    }

    func clearingNamedGeometry() -> any Geometry2D {
        withResult(NamedGeometry())
    }
}

public extension Geometry3D {
    func named(_ name: String, transform context: TransformContext = .global) -> any Geometry3D {
        EnvironmentReader { environment in
            modifyingResult(NamedGeometry.self) { oldValue in
                (oldValue ?? .init()).adding(context.prepare(self, in: environment), named: name)
            }
        }
    }

    func prefixingNames(_ prefix: String) -> any Geometry3D {
        modifyingResult(NamedGeometry.self) { namedGeometry in
            namedGeometry?.transformingNames { prefix + $0 }
        }
    }

    func suffixingNames(_ suffix: String) -> any Geometry3D {
        modifyingResult(NamedGeometry.self) { namedGeometry in
            namedGeometry?.transformingNames { $0 + suffix }
        }
    }

    func clearingNamedGeometry() -> any Geometry3D {
        withResult(NamedGeometry())
    }
}
