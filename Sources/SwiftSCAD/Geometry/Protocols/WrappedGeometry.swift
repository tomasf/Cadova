import Foundation

internal protocol WrappedGeometry2D: Geometry2D {
    var body: any Geometry2D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    var needsColorDeclaration: Bool { get }
    func boundary(bodyBoundary: Bounds) -> Bounds
}

extension WrappedGeometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        .init(
            bodyOutput: body.evaluated(in: environment),
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            declaresColor: needsColorDeclaration,
            environment: environment
        ) {
            boundary(bodyBoundary: $0)
        }
    }

    func boundary(bodyBoundary: Bounds) -> Bounds { bodyBoundary }
    public var moduleParameters: CodeFragment.Parameters { [:] }
    public var needsColorDeclaration: Bool { false }
}

internal protocol WrappedGeometry3D: Geometry3D {
    var body: any Geometry3D { get }
    var moduleName: String { get }
    var moduleParameters: CodeFragment.Parameters { get }
    var needsColorDeclaration: Bool { get }
    func boundary(bodyBoundary: Bounds) -> Bounds
}

extension WrappedGeometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output {
        .init(
            bodyOutput: body.evaluated(in: environment),
            moduleName: moduleName,
            moduleParameters: moduleParameters,
            declaresColor: needsColorDeclaration,
            environment: environment
        ) {
            boundary(bodyBoundary: $0)
        }
    }

    func boundary(bodyBoundary: Bounds) -> Bounds { bodyBoundary }
    public var moduleParameters: CodeFragment.Parameters { [:] }
    public var needsColorDeclaration: Bool { false }
}
