import Foundation

public struct Align2D: Shape2D {
    let content: any Geometry2D
    let alignment: GeometryAlignment2D

    public var body: any Geometry2D {
        EnvironmentReader { environment in
            let boundary = content.boundary(in: environment)
            let translation = boundary.boundingBox?.translation(for: alignment) ?? .zero
            content
                .translated(translation)
        }
    }
}

public struct Align3D: Shape3D {
    let content: any Geometry3D
    let alignment: GeometryAlignment3D

    public var body: any Geometry3D {
        EnvironmentReader { environment in
            let boundary = content.boundary(in: environment)
            let translation = boundary.boundingBox?.translation(for: alignment) ?? .zero
            content
                .translated(translation)
        }
    }
}
