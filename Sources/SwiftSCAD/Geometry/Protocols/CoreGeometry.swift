import Foundation

protocol CoreGeometry2D: Geometry2D {
    func call(in environment: Environment) -> SCADCall
    var bodyTransform: AffineTransform3D { get }
}

extension CoreGeometry2D {
    public func scadString(in environment: Environment) -> String {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        return call(in: newEnvironment)
            .scadString(in: newEnvironment)
    }

    var bodyTransform: AffineTransform3D { .identity }
}


protocol CoreGeometry3D: Geometry3D {
    func call(in environment: Environment) -> SCADCall
    var bodyTransform: AffineTransform3D { get }
}

extension CoreGeometry3D {
    public func scadString(in environment: Environment) -> String {
        let newEnvironment = environment.applyingTransform(bodyTransform)
        return call(in: newEnvironment)
            .scadString(in: newEnvironment)
    }

    var bodyTransform: AffineTransform3D { .identity }
}
