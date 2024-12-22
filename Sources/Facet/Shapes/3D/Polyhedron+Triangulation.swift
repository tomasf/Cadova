import Foundation

internal extension Polyhedron {
    // Triangulation using the ear clipping method

    func triangulated() -> Polyhedron {
        func isPointInTriangle(_ p: Vector3D, _ a: Vector3D, _ b: Vector3D, _ c: Vector3D) -> Bool {
            let v0 = c - a
            let v1 = b - a
            let v2 = p - a

            let dot00 = v0 ⋅ v0
            let dot01 = v0 ⋅ v1
            let dot02 = v0 ⋅ v2
            let dot11 = v1 ⋅ v1
            let dot12 = v1 ⋅ v2

            let invDenom = 1 / (dot00 * dot11 - dot01 * dot01)
            let u = (dot11 * dot02 - dot01 * dot12) * invDenom
            let v = (dot00 * dot12 - dot01 * dot02) * invDenom

            return (u >= 0) && (v >= 0) && (u + v < 1)
        }

        var triangles: [[Int]] = []

        for face in faces {
            guard face.count > 3 else {
                triangles.append(face)
                continue
            }

            // Get the normal vector of the face to check orientation
            let normal = vertices[face[1]] - vertices[face[0]] × vertices[face[2]] - vertices[face[0]]

            var remainingIndices = face
            while remainingIndices.count > 3 {
                var earFound = false
                for i in 0..<remainingIndices.count {
                    let prevIndex = (i - 1 + remainingIndices.count) % remainingIndices.count
                    let nextIndex = (i + 1) % remainingIndices.count

                    let a = vertices[remainingIndices[prevIndex]]
                    let b = vertices[remainingIndices[i]]
                    let c = vertices[remainingIndices[nextIndex]]

                    // Check if the triangle normal matches the face normal
                    if (b - a × c - a) ⋅ normal <= 0 {
                        continue
                    }

                    // Check if any other point lies inside the triangle
                    var pointInside = false
                    for j in 0..<remainingIndices.count {
                        if j == prevIndex || j == i || j == nextIndex { continue }

                        let p = vertices[remainingIndices[j]]
                        if isPointInTriangle(p, a, b, c) {
                            pointInside = true
                            break
                        }
                    }

                    if !pointInside {
                        triangles.append([remainingIndices[prevIndex], remainingIndices[i], remainingIndices[nextIndex]])
                        remainingIndices.remove(at: i) // Remove the ear vertex
                        earFound = true
                        break
                    }
                }

                if !earFound {
                    fatalError("Failed to triangulate face. Check for issues with coplanarity or invalid input.")
                }
            }

            // Add the final triangle
            if remainingIndices.count == 3 {
                triangles.append([remainingIndices[0], remainingIndices[1], remainingIndices[2]])
            }
        }

        return Polyhedron(vertices: vertices, faces: triangles)
    }
}
