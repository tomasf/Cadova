import Foundation

internal struct SetVariables<Geometry> {
    let body: Geometry
    let variables: CodeFragment.Parameters

    let moduleName = "let"
    var moduleParameters: CodeFragment.Parameters { variables }
}

extension SetVariables<any Geometry2D>: Geometry2D, WrappedGeometry2D {}
extension SetVariables<any Geometry3D>: Geometry3D, WrappedGeometry3D {}
