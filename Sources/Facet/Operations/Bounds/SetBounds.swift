import Foundation

internal struct SetBounds<V: Vector> {
    let body: V.Geometry
    let boundary: Boundary<V>
}

extension SetBounds<Vector2D>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        let bodyOutput = body.evaluated(in: environment)
        return .init(codeFragment: bodyOutput.codeFragment, boundary: boundary, elements: bodyOutput.elements)
    }
}

extension SetBounds<Vector3D>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let bodyOutput = body.evaluated(in: environment)
        return .init(codeFragment: bodyOutput.codeFragment, boundary: boundary, elements: bodyOutput.elements)
    }
}


public extension Geometry2D {
    /// Defines the bounds of the geometry as the specified 2D bounding box.
    /// - Parameter box: The bounding box to set for the geometry.
    /// - Returns: A  geometry with the specified bounds.
    func settingBounds(_ box: BoundingBox2D) -> any Geometry2D {
        SetBounds(body: self, boundary: .init(boundingBox: box))
    }

    /// Defines the bounds of the geometry based on a custom 2D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(@GeometryBuilder2D _ shape: () -> any Geometry2D) -> any Geometry2D {
        shape().readingBoundary { _, boundary in
            SetBounds(body: self, boundary: boundary)
        }
    }

    /// Defines the bounds of the geometry based on a custom 2D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(_ shape: any Geometry2D) -> any Geometry2D {
        shape.readingBoundary { _, boundary in
            SetBounds(body: self, boundary: boundary)
        }
    }

    func modifyingBounds(modification: @escaping (BoundingBox2D?) -> BoundingBox2D) -> any Geometry2D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds(modification(bounds))
        }
    }

    func modifyingBounds(@GeometryBuilder2D _ shape: @escaping (BoundingBox2D?) -> any Geometry2D) -> any Geometry2D {
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
        SetBounds(body: self, boundary: .init(boundingBox: box))
    }

    /// Defines the bounds of the geometry based on a custom 3D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(@GeometryBuilder3D _ shape: () -> any Geometry3D) -> any Geometry3D {
        shape().readingBoundary { _, boundary in
            SetBounds(body: self, boundary: boundary)
        }
    }

    /// Defines the bounds of the geometry based on a custom 3D shape.
    /// - Parameter shape: The shape whose bounds you want to use.
    /// - Returns: A geometry with the bounds obtained from the custom shape.
    func settingBounds(_ shape: any Geometry3D) -> any Geometry3D {
        shape.readingBoundary { _, boundary in
            SetBounds(body: self, boundary: boundary)
        }
    }

    func modifyingBounds(modification: @escaping (BoundingBox3D?) -> BoundingBox3D) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds(modification(bounds))
        }
    }

    func modifyingBounds(@GeometryBuilder3D _ shape: @escaping (BoundingBox3D?) -> any Geometry3D) -> any Geometry3D {
        measuringBounds { geometry, bounds in
            geometry.settingBounds { shape(bounds) }
        }
    }
}
