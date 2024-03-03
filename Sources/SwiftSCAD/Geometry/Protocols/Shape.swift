import Foundation

public protocol Shape3D: Geometry3D {
    @UnionBuilder3D var body: any Geometry3D { get }
}

public extension Shape3D {
    func scadString(in environment: Environment) -> String {
        body.scadString(in: environment)
    }
}


public protocol Shape2D: Geometry2D {
    @UnionBuilder2D var body: any Geometry2D { get }
}

public extension Shape2D {
    func scadString(in environment: Environment) -> String {
        body.scadString(in: environment)
    }
}
