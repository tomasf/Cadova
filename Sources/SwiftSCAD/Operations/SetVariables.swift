import Foundation

struct SetVariables2D: WrapperGeometry2D {
    let body: any Geometry2D
    let variables: Invocation.Parameters
    let environment: ((Environment) -> Environment)?

    var invocation: Invocation? {
        .init(name: "let", parameters: variables)
    }

    func modifiedEnvironment(_ e: Environment) -> Environment {
        environment?(e) ?? e
    }
}

struct SetVariables3D: WrapperGeometry3D {
    let body: any Geometry3D
    let variables: Invocation.Parameters
    let environment: ((Environment) -> Environment)?

    var invocation: Invocation? {
        .init(name: "let", parameters: variables)
    }

    func modifiedEnvironment(_ e: Environment) -> Environment {
        environment?(e) ?? e
    }
}
