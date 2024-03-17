import Foundation

struct SetBounds2D: WrappedGeometry2D {
    let body: any Geometry2D
    let boundary: Boundary2D

    let invocation: Invocation? = nil

    func modifiedOutput(_ output: Output) -> Output {
        output.modifyingBoundary { _ in boundary }
    }
}

struct SetBounds3D: WrappedGeometry3D {
    let body: any Geometry3D
    let boundary: Boundary3D

    let invocation: Invocation? = nil

    func modifiedOutput(_ output: Output) -> Output {
        output.modifyingBoundary { _ in boundary }
    }
}

public extension Geometry2D {
    func settingBounds(_ box: BoundingBox2D) -> any Geometry2D {
        SetBounds2D(body: self, boundary: .init(boundingBox: box))
    }

    func settingBounds(@UnionBuilder2D _ shape: () -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: shape()) { _, boundary in
            SetBounds2D(body: self, boundary: boundary)
        }
    }
}

public extension Geometry3D {
    func settingBounds(_ box: BoundingBox3D) -> any Geometry3D {
        SetBounds3D(body: self, boundary: .init(boundingBox: box))
    }

    func settingBounds(@UnionBuilder3D _ shape: () -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: shape()) { _, boundary in
            SetBounds3D(body: self, boundary: boundary)
        }
    }
}
