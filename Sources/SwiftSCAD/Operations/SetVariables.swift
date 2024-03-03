import Foundation

struct SetVariables3D: CoreGeometry3D {
    let variables: [String: any SCADValue]
    let environment: ((Environment) -> Environment)?
    let body: any Geometry3D

    func call(in e: Environment) -> SCADCall {
        SCADCall(name: "let", params: variables, body: body, bodyEnvironment: environment?(e) ?? e)
    }
}

struct SetVariables2D: CoreGeometry2D {
    let variables: [String: any SCADValue]
    let environment: ((Environment) -> Environment)?
    let body: any Geometry2D

    func call(in e: Environment) -> SCADCall {
        SCADCall(name: "let", params: variables, body: body, bodyEnvironment: environment?(e) ?? e)
    }
}
