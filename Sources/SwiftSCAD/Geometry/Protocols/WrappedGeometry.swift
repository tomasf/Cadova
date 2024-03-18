import Foundation

protocol WrappedGeometry2D: Geometry2D {
    var invocation: Invocation? { get }
    var body: any Geometry2D { get }
    var bodyTransform: AffineTransform3D { get }
    func modifiedEnvironment(_ environment: Environment) -> Environment
    func modifiedOutput(_ output: Output) -> Output
}

extension WrappedGeometry2D {
    public var bodyTransform: AffineTransform3D { .identity }

    public func output(in environment: Environment) -> Output {
        if let invocation {
            return modifiedOutput(.init(
                invocation: invocation,
                body: [body],
                bodyTransform: bodyTransform,
                environment: modifiedEnvironment(environment)
            ))
        } else {
            return modifiedOutput(body.output(in: modifiedEnvironment(environment)))
        }
    }

    public func modifiedEnvironment(_ e: Environment) -> Environment { e }
    public func modifiedOutput(_ output: Output) -> Output { output }
}

protocol WrappedGeometry3D: Geometry3D {
    var invocation: Invocation? { get }
    var body: any Geometry3D { get }
    var bodyTransform: AffineTransform3D { get }
    func modifiedEnvironment(_ environment: Environment) -> Environment
    func modifiedOutput(_ output: Output) -> Output
}

extension WrappedGeometry3D {
    public var bodyTransform: AffineTransform3D { .identity }

    public func output(in environment: Environment) -> Output {
        if let invocation {
            return modifiedOutput(
                .init(
                    invocation: invocation,
                    body: [body],
                    bodyTransform: bodyTransform,
                    environment: modifiedEnvironment(environment)
                )
            )
        } else {
            return modifiedOutput(body.output(in: modifiedEnvironment(environment)))
        }
    }

    public func modifiedEnvironment(_ e: Environment) -> Environment { e }
    public func modifiedOutput(_ output: Output) -> Output { output }
}
