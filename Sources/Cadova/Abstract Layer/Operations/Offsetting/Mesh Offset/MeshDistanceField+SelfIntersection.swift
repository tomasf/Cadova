import Foundation

extension MeshDistanceField {
    /// Whether a face crosses another face it doesn't share a corner with, as where a mesh intersects itself: there,
    /// a face lies partly inside the solid, so its pseudonormals can't be trusted anywhere along it
    func intersectsOtherFaces(_ index: Int) -> Bool {
        let face = faces[index]
        let a = vertexBuffer[face.0], b = vertexBuffer[face.1], c = vertexBuffer[face.2]
        // Grown by the tolerance coplanar faces are allowed: flat faces off each other's plane by less than it
        // still overlap, though their boxes miss each other
        let margin = Vector3D(planeTolerance, planeTolerance, planeTolerance)
        let lower = Vector3D.min(a, .min(b, c)) - margin, upper = Vector3D.max(a, .max(b, c)) + margin
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let nodeIndex = stack[top]
                let box = boxes.baseAddress! + 6 * nodeIndex
                if box[0] > upper.x || box[3] < lower.x || box[1] > upper.y || box[4] < lower.y || box[2] > upper.z || box[5] < lower.z { continue }
                let node = nodes[nodeIndex]
                if node.left < 0 {
                    var i = node.first
                    while i < node.first + node.count {
                        let other = order[i]
                        i += 1
                        guard other != index else { continue }
                        let o = faces[other]
                        let p = vertexBuffer[o.0], q = vertexBuffer[o.1], r = vertexBuffer[o.2]
                        // Faces whose boxes don't touch can neither overlap nor cross
                        if min(p.x, min(q.x, r.x)) > upper.x || max(p.x, max(q.x, r.x)) < lower.x
                            || min(p.y, min(q.y, r.y)) > upper.y || max(p.y, max(q.y, r.y)) < lower.y
                            || min(p.z, min(q.z, r.z)) > upper.z || max(p.z, max(q.z, r.z)) < lower.z { continue }
                        // Coplanar faces can overlap even where they share a corner, as where a sheet folds flat
                        // onto its neighbor's; a shared corner alone lies on both, which doesn't count as overlap
                        if Self.coplanarTrianglesOverlap(a, b, c, normal: faceNormals[index], p, q, r, tolerance: planeTolerance) { return true }
                        // Faces sharing a corner meet there by construction
                        if o.0 == face.0 || o.0 == face.1 || o.0 == face.2 || o.1 == face.0 || o.1 == face.1 || o.1 == face.2
                            || o.2 == face.0 || o.2 == face.1 || o.2 == face.2 { continue }
                        if Self.segmentCrossesTriangle(a, b, p, q, r) || Self.segmentCrossesTriangle(b, c, p, q, r)
                            || Self.segmentCrossesTriangle(c, a, p, q, r) || Self.segmentCrossesTriangle(p, q, a, b, c)
                            || Self.segmentCrossesTriangle(q, r, a, b, c) || Self.segmentCrossesTriangle(r, p, a, b, c) {
                            return true
                        }
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return false
        }
    }

    /// Whether two triangles lie in one plane and overlap there, as where two sheets touch face to face: between
    /// them is no solid, whichever way their normals point
    static func coplanarTrianglesOverlap(_ a: Vector3D, _ b: Vector3D, _ c: Vector3D, normal: Vector3D, _ p: Vector3D, _ q: Vector3D, _ r: Vector3D, tolerance: Double) -> Bool {
        guard normal != .zero else { return false }
        let offset = normal ⋅ a
        guard abs(normal ⋅ p - offset) <= tolerance, abs(normal ⋅ q - offset) <= tolerance, abs(normal ⋅ r - offset) <= tolerance else { return false }
        // In the plane of the axes the normal is least aligned with. Plain values throughout: this runs for every
        // pair of nearby faces, and small arrays and closures are slow in unoptimized builds.
        let nx = abs(normal.x), ny = abs(normal.y), nz = abs(normal.z)
        let drop = nx >= ny && nx >= nz ? 0 : (ny >= nz ? 1 : 2)
        func flat(_ v: Vector3D) -> (Double, Double) { drop == 0 ? (v.y, v.z) : drop == 1 ? (v.z, v.x) : (v.x, v.y) }
        let a2 = flat(a), b2 = flat(b), c2 = flat(c), p2 = flat(p), q2 = flat(q), r2 = flat(r)
        func cross(_ o: (Double, Double), _ u: (Double, Double), _ v: (Double, Double)) -> Double {
            (u.0 - o.0) * (v.1 - o.1) - (u.1 - o.1) * (v.0 - o.0)
        }
        // Separated if an edge of either has the whole other triangle strictly on its outer side
        func separates(_ u: (Double, Double), _ v: (Double, Double), _ orientation: Double,
                       _ x: (Double, Double), _ y: (Double, Double), _ z: (Double, Double)) -> Bool {
            cross(u, v, x) * orientation <= 0 && cross(u, v, y) * orientation <= 0 && cross(u, v, z) * orientation <= 0
        }
        let firstOrientation = cross(a2, b2, c2), secondOrientation = cross(p2, q2, r2)
        guard firstOrientation != 0, secondOrientation != 0 else { return false }
        if separates(a2, b2, firstOrientation, p2, q2, r2) || separates(b2, c2, firstOrientation, p2, q2, r2)
            || separates(c2, a2, firstOrientation, p2, q2, r2) { return false }
        if separates(p2, q2, secondOrientation, a2, b2, c2) || separates(q2, r2, secondOrientation, a2, b2, c2)
            || separates(r2, p2, secondOrientation, a2, b2, c2) { return false }
        return true
    }

    /// Whether the segment from s to e passes through the triangle (a, b, c), strictly: two non-coplanar triangles
    /// intersect exactly when an edge of one passes through the other
    static func segmentCrossesTriangle(_ s: Vector3D, _ e: Vector3D, _ a: Vector3D, _ b: Vector3D, _ c: Vector3D) -> Bool {
        // (q − p) ⋅ ((r − p) × (t − p)) in scalars, in the same order: vector operations check their elements are
        // finite, which unoptimized builds don't inline, and this runs for every pair of nearby faces
        func volume(_ p: Vector3D, _ q: Vector3D, _ r: Vector3D, _ t: Vector3D) -> Double {
            let ux = q.x - p.x, uy = q.y - p.y, uz = q.z - p.z
            let vx = r.x - p.x, vy = r.y - p.y, vz = r.z - p.z
            let wx = t.x - p.x, wy = t.y - p.y, wz = t.z - p.z
            return ux * (vy * wz - vz * wy) + uy * (vz * wx - vx * wz) + uz * (vx * wy - vy * wx)
        }
        let side1 = volume(a, b, c, s), side2 = volume(a, b, c, e)
        guard (side1 > 0 && side2 < 0) || (side1 < 0 && side2 > 0) else { return false }
        let v1 = volume(s, e, a, b), v2 = volume(s, e, b, c), v3 = volume(s, e, c, a)
        return (v1 > 0 && v2 > 0 && v3 > 0) || (v1 < 0 && v2 < 0 && v3 < 0)
    }
}
