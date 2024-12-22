import Foundation

internal struct ModifyPrimitive<D: Dimensionality> {
    let body: D.Geometry
    let modification: (D.Primitive) -> D.Primitive
}

extension ModifyPrimitive: Geometry3D where D == Dimensionality3 {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let output = body.evaluated(in: environment)
        return output.modifyingManifold { mesh in
            modification(mesh)
        }
    }
}

public extension Geometry3D {
    func warp(_ transform: @escaping (Vector3D) -> Vector3D) -> any Geometry3D {
        ModifyPrimitive(body: self) { mesh in
            mesh.warp { v3 in
                transform(Vector3D(v3))
            }
        }
    }
}
