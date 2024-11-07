import Foundation
import Collections

/// An arbitrary three-dimensional shape made up of flat faces.
///
/// For more information, see [the OpenSCAD documentation](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Primitive_Solids#polyhedron).

public struct Polyhedron: LeafGeometry3D {
    let points: [Vector3D]
    let faces: [[Array<Vector3D>.Index]]

    internal init(points: [Vector3D], faces: [[Array<Vector3D>.Index]]) {
        assert(points.count >= 4, "At least four points are needed for a polyhedron")
        assert(faces.allSatisfy { $0.count >= 3 }, "Each face must contain at least three points")

        self.points = points
        self.faces = faces
    }

    let moduleName = "polyhedron"
    var moduleParameters: CodeFragment.Parameters {
        ["points": points, "faces": faces]
    }

    func boundary(in environment: EnvironmentValues) -> Bounds {
        .points(points)
    }

    let supportsPreviewConvexity = true
}

public extension Polyhedron {
    /// Create a polyhedron from faces
    /// - Parameters:
    ///   - faces: A list of faces made up of hashable keys representing points. Faces must cover the entire shape without any holes.
    ///   - value: A closure that provides the concrete vector for a key
    ///
    init<
        Key: Hashable, Face: Sequence<Key>, FaceList: Sequence<Face>
    >(faces: FaceList, value: (Key) -> Vector3D) {
        var pointValues: [Vector3D] = []
        let orderedKeys = OrderedSet(faces.joined())
        let keyIndices: [Key: Int] = orderedKeys.reduce(into: [:]) { table, key in
            pointValues.append(value(key))
            table[key] = pointValues.endIndex - 1
        }

        self.init(points: pointValues, faces: faces.map {
            $0.map {
                guard let index = keyIndices[$0] else {
                    preconditionFailure("Undefined point key: \($0)")
                }
                return index
            }
        })
    }

    init<Face: Sequence<Vector3D>, FaceList: Sequence<Face>>(faces: FaceList) {
        self.init(faces: faces, value: \.self)
    }
}
