import Foundation
import Collections

/// An arbitrary three-dimensional shape made up of flat faces.
///
/// For more information, see [the OpenSCAD documentation](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Primitive_Solids#polyhedron).

public struct Polyhedron: LeafGeometry3D {
    let points: [Vector3D]
    let faces: [[Int]]
    let convexity: Int

    /// Create a polyhedron from a list of points and faces made up of indexes in that list of points.
    /// - Parameters:
    ///   - points: The vertices of the polyhedron. At least four are required to form a valid shape.
    ///   - faces: A list of faces that must cover the entire shape without any holes, where each face consists of a list of points by index in `points`.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.

    public init(points: [Vector3D], faces: [[Int]], convexity: Int = 2) {
        assert(points.count >= 4, "At least four points are needed for a polyhedron")
        assert(faces.allSatisfy { $0.count >= 3 }, "Each face must contain at least three points")
        assert(faces.allSatisfy { $0.allSatisfy { $0 < points.count } }, "Each face must contain indexes from the points array")

        self.points = points
        self.faces = faces
        self.convexity = convexity
    }

    /// Create a polyhedron from a list of faces
    /// - Parameters:
    ///   - faces: A list of faces that must cover the entire shape without any holes, where each face consists of vertex vectors.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.

    public init(faces vectorFaces: [[Vector3D]], convexity: Int = 2) {
        var points: [Vector3D] = []

        let faces = vectorFaces.map { vectors -> [Int] in
            assert(vectors.count >= 3, "Each face must contain at least three points")

            return vectors.map { vector in
                if let index = points.firstIndex(of: vector) {
                    return Int(index)
                } else {
                    points.append(vector)
                    return points.count - 1
                }
            }
        }

        self.init(points: points, faces: faces, convexity: convexity)
    }

    /// Create a polyhedron from a table of keys and faces made up of such keys
    /// - Parameters:
    ///   - points: A lookup table of keys to the points they represent.
    ///   - faces: A list of faces using keys from the `points` parameter. Faces must cover the entire shape without any holes.
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.

    public init<Key: Hashable>(points: [Key: Vector3D], faces: [OrderedSet<Key>], convexity: Int = 2) {
        var pointValues: [Vector3D] = []
        let indexMapping = points.mapValues { vector -> Int in
            pointValues.append(vector)
            return pointValues.endIndex - 1
        }

        let facesWithIndexes = faces.map {
            $0.map { key -> Int in
                guard let index = indexMapping[key] else {
                    preconditionFailure("Undefined point key: \(key)")
                }
                return index
            }
        }

        self.init(points: pointValues, faces: facesWithIndexes, convexity: convexity)
    }

    /// Create a polyhedron from faces
    /// - Parameters:
    ///   - faces: A list of faces made up of hashable items representing points. Faces must cover the entire shape without any holes.
    ///   - value: A closure that provides the concrete vector for an item
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    public init<Point: Hashable>(faces: [OrderedSet<Point>], convexity: Int = 2, value: (Point) -> Vector3D) {
        let table: [Point: Vector3D] = Set(faces.joined()).reduce(into: [:]) { table, vertex in
            table[vertex] = value(vertex)
        }
        self.init(points: table, faces: faces, convexity: convexity)
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
