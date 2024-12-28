import Foundation

public extension Geometry2D {
    func warp(_ transform: @escaping (Vector2D) -> Vector2D) -> any Geometry2D {
        modifyingPrimitive { mesh, _ in
            mesh.warp { v2 in
                transform(Vector2D(v2))
            }
        }
    }
}

public extension Geometry3D {
    func warp(_ transform: @escaping (Vector3D) -> Vector3D) -> any Geometry3D {
        modifyingPrimitive { mesh, _ in
            mesh.warp { v3 in
                transform(Vector3D(v3))
            }
        }
    }
}
