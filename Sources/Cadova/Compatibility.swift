import Foundation

public extension Geometry3D {
    @available(*, deprecated, message: "Use Model instead.")
    func save(to path: String) async {
        await Model(path, content: { self })
    }
}

public extension Geometry2D {
    @available(*, deprecated, message: "Use Model instead.")
    func save(to path: String) async {
        await Model(path, content: { self })
    }
}

