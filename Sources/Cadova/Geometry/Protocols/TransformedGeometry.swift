import Foundation

internal protocol TransformedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    var bodyTransform: AffineTransform2D { get }
}

extension TransformedGeometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        let bodyEnvironment = environment.applyingTransform(bodyTransform.transform3D)
        let bodyOutput = body.evaluated(in: bodyEnvironment)
        return bodyOutput.applyingTransform(.init(bodyTransform))
    }
}

internal protocol TransformedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var bodyTransform: AffineTransform3D { get }
}

extension TransformedGeometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        let bodyEnvironment = environment.applyingTransform(bodyTransform)
        let bodyOutput = body.evaluated(in: bodyEnvironment)
        return bodyOutput.applyingTransform(bodyTransform)
    }
}
