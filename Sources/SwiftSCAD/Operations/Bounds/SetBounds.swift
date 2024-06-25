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
    /// Defines the bounds of the geometry as the specified 2D bounding box.
    /// - Parameter box: The bounding box to set for the geometry.
    /// - Returns: A  geometry with the specified bounds.
    func settingBounds(_ box: BoundingBox2D) -> any Geometry2D {
        SetBounds2D(body: self, boundary: .init(boundingBox: box))
    }

    /// Defines the bounds of the geometry based on a custom 2D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(@UnionBuilder2D _ shape: () -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: shape()) { _, boundary in
            SetBounds2D(body: self, boundary: boundary)
        }
    }

    /// Defines the bounds of the geometry based on a custom 2D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(_ shape: any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: shape) { _, boundary in
            SetBounds2D(body: self, boundary: boundary)
        }
    }

    func modifyingBounds(modification: @escaping (BoundingBox2D) -> BoundingBox2D) -> any Geometry2D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds(modification(bounds))
        }
    }

    func modifyingBounds(@UnionBuilder2D _ shape: @escaping (BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds { shape(bounds) }
        }
    }
}

public extension Geometry3D {
    /// Defines the bounds of the geometry as the specified 3D bounding box.
    /// - Parameter box: The bounding box to set for the geometry.
    /// - Returns: A  geometry with the specified bounds.
    func settingBounds(_ box: BoundingBox3D) -> any Geometry3D {
        SetBounds3D(body: self, boundary: .init(boundingBox: box))
    }

    /// Defines the bounds of the geometry based on a custom 3D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(@UnionBuilder3D _ shape: () -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: shape()) { _, boundary in
            SetBounds3D(body: self, boundary: boundary)
        }
    }

    /// Defines the bounds of the geometry based on a custom 3D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(_ shape: any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: shape) { _, boundary in
            SetBounds3D(body: self, boundary: boundary)
        }
    }

    func modifyingBounds(modification: @escaping (BoundingBox3D) -> BoundingBox3D) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds(modification(bounds))
        }
    }

    func modifyingBounds(@UnionBuilder3D _ shape: @escaping (BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds { shape(bounds) }
        }
    }
}
