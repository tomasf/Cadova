import Foundation

struct SetVariables2D: WrappedGeometry2D {
    let body: any Geometry2D
    let variables: CodeFragment.Parameters

    let moduleName = "let"
    var moduleParameters: CodeFragment.Parameters { variables }
}

struct SetVariables3D: WrappedGeometry3D {
    let body: any Geometry3D
    let variables: CodeFragment.Parameters

    let moduleName = "let"
    var moduleParameters: CodeFragment.Parameters { variables }
}
