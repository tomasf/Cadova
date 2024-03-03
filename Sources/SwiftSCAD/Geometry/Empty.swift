import Foundation

internal struct Empty: Geometry3D, Geometry2D {
    func scadString(in environment: Environment) -> String {
        ";"
    }
}
