import Foundation
import Collections

/// An arbitrary three-dimensional shape made up of flat faces.
///
/// For more information, see [the OpenSCAD documentation](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Primitive_Solids#polyhedron).

public struct Polyhedron: LeafGeometry3D {
    let points: [Vector3D]
    let faces: [[Array<Vector3D>.Index]]
    let convexity: Int

    internal init(points: [Vector3D], faces: [[Array<Vector3D>.Index]], convexity: Int = 2) {
        assert(points.count >= 4, "At least four points are needed for a polyhedron")
        assert(faces.allSatisfy { $0.count >= 3 }, "Each face must contain at least three points")

        self.points = points
        self.faces = faces
        self.convexity = convexity
    }

    let moduleName = "polyhedron"
    var moduleParameters: CodeFragment.Parameters {
        [
            "points": points,
            "faces": faces,
            "convexity": convexity
        ]
    }

    var boundary: Bounds {
        .points(points)
    }
}

public extension Polyhedron {
    /// Create a polyhedron from faces
    /// - Parameters:
    ///   - faces: A list of faces made up of hashable keys representing points. Faces must cover the entire shape without any holes.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    ///   - value: A closure that provides the concrete vector for a key
    ///
    init<
        Key: Hashable, Face: Sequence<Key>, FaceList: Sequence<Face>
    >(faces: FaceList, convexity: Int = 2, value: (Key) -> Vector3D) {
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
        }, convexity: convexity)
    }
}
