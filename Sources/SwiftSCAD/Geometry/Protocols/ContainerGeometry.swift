import Foundation

protocol ContainerGeometry2D: Geometry2D {
    func geometry(in environment: Environment) -> any Geometry2D
    func modifiedEnvironment(_ environment: Environment) -> Environment
}

extension ContainerGeometry2D {
    public func scadString(in environment: Environment) -> String {
        let newEnvironment = modifiedEnvironment(environment)
        return geometry(in: newEnvironment).scadString(in: newEnvironment)
    }

    func modifiedEnvironment(_ environment: Environment) -> Environment { environment }
}


protocol ContainerGeometry3D: Geometry3D {
    func geometry(in environment: Environment) -> any Geometry3D
    func modifiedEnvironment(_ environment: Environment) -> Environment
}

extension ContainerGeometry3D {
    public func scadString(in environment: Environment) -> String {
        let newEnvironment = modifiedEnvironment(environment)
        return geometry(in: newEnvironment).scadString(in: newEnvironment)
    }

    func modifiedEnvironment(_ environment: Environment) -> Environment { environment }
}
