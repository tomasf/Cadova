import Foundation

struct SetVariables2D: WrappedGeometry2D {
    let body: any Geometry2D
    let variables: Invocation.Parameters

    let invocationName: String? = "let"
    var invocationParameters: Invocation.Parameters { variables }
}

struct SetVariables3D: WrappedGeometry3D {
    let body: any Geometry3D
    let variables: Invocation.Parameters

    let invocationName: String? = "let"
    var invocationParameters: Invocation.Parameters { variables }
}
