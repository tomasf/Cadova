import Foundation

extension MeshDistanceField {
    /// Generalized winding number: about 1 inside, 0 outside
    func windingNumber(at p: Vector3D) -> Double {
        guard !nodes.isEmpty else { return 0 }
        var total = 0.0
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let index = stack[top]
                let node = nodes[index]
                let toward = node.center - p
                let distance = toward.magnitude
                if distance > 2 * node.radius {
                    total += (node.area ⋅ toward) / (distance * distance * distance)
                    continue
                }
                if node.left < 0 {
                    var i = node.first
                    while i < node.first + node.count {
                        let face = faces[order[i]]
                        let a = vertexBuffer[face.0] - p, b = vertexBuffer[face.1] - p, c = vertexBuffer[face.2] - p
                        let la = a.magnitude, lb = b.magnitude, lc = c.magnitude
                        total += 2 * Foundation.atan2(a ⋅ (b × c), la * lb * lc + (a ⋅ b) * lc + (a ⋅ c) * lb + (b ⋅ c) * la)
                        i += 1
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return total / (4 * .pi)
        }
    }

    /// Whether p is inside. The pseudonormal decides when it clearly can; where it involves defective faces, or runs
    /// nearly along the surface, the winding number does.
    func isInside(_ p: Vector3D, closest: Closest) -> Bool {
        let toward = p - closest.point
        let along = toward ⋅ closest.pseudonormal
        let lengths = toward.magnitude * closest.pseudonormal.magnitude
        if closest.isReliable, lengths > 0, abs(along) > 0.2 * lengths {
            return along < 0
        }
        return windingNumber(at: p) > 0.5
    }

    func signedDistance(at p: Vector3D, hint: Int? = nil) -> Double {
        signedDistanceAndFace(at: p, hint: hint).value
    }

    /// The signed distance, and the face the closest point lies on (a hint for nearby queries)
    func signedDistanceAndFace(at p: Vector3D, hint: Int? = nil) -> (value: Double, face: Int) {
        let closest = closest(to: p, hint: hint)
        let distance = closest.distanceSquared.squareRoot()
        return (isInside(p, closest: closest) ? -distance : distance, closest.face)
    }

    /// The signed distance, its gradient (the unit direction away from the surface), and the closest face
    func signedDistanceAndGradient(at p: Vector3D, hint: Int? = nil) -> (value: Double, gradient: Vector3D, face: Int) {
        let closest = closest(to: p, hint: hint)
        let toward = p - closest.point
        let distance = closest.distanceSquared.squareRoot()
        let inside = isInside(p, closest: closest)
        let gradient = distance > 0 ? toward * ((inside ? -1 : 1) / distance) : closest.pseudonormal.safelyNormalized
        return (inside ? -distance : distance, gradient, closest.face)
    }

    /// Whether every face within `radius` of p lies in one plane (or there are none). The offset surface near p is
    /// then provably that plane moved along its normal.
    func facesAreCoplanar(within radius: Double, of p: Vector3D) -> Bool {
        coplanarNormal(within: radius, of: p).coplanar
    }

    /// The same, and the plane's normal, if there are faces within reach
    func coplanarNormal(within radius: Double, of p: Vector3D) -> (coplanar: Bool, normal: Vector3D?) {
        guard !nodes.isEmpty else { return (true, nil) }
        let radiusSquared = radius * radius
        var reference: (normal: Vector3D, offset: Double)? = nil
        let coplanar = withUnsafeTemporaryAllocation(of: Int.self, capacity: 128) { stack in
            var top = 1
            stack[0] = 0
            while top > 0 {
                top -= 1
                let index = stack[top]
                let node = nodes[index]
                if boxDistanceSquared(index, p.x, p.y, p.z) > radiusSquared { continue }
                if node.left < 0 {
                    var i = node.first
                    while i < node.first + node.count {
                        let faceIndex = order[i]
                        i += 1
                        if facePoint(faceIndex, p.x, p.y, p.z).distanceSquared > radiusSquared { continue }
                        let face = faces[faceIndex]
                        let normal = faceNormals[faceIndex]
                        // A degenerate face has no plane of its own; its corners still have to lie on the others'
                        if normal == .zero && reference == nil { continue }
                        guard let plane = reference else {
                            reference = (normal, normal ⋅ vertexBuffer[face.0])
                            continue
                        }
                        // Corners on the plane decide; the normal only has to face the same way, since meshes with
                        // single-precision coordinates tilt small faces' normals slightly
                        if normal != .zero && normal ⋅ plane.normal < 0.99 { return false }
                        if abs(plane.normal ⋅ vertexBuffer[face.0] - plane.offset) > planeTolerance
                            || abs(plane.normal ⋅ vertexBuffer[face.1] - plane.offset) > planeTolerance
                            || abs(plane.normal ⋅ vertexBuffer[face.2] - plane.offset) > planeTolerance {
                            return false
                        }
                    }
                    continue
                }
                stack[top] = node.left; stack[top + 1] = node.right; top += 2
            }
            return true
        }
        return (coplanar, coplanar ? reference?.normal : nil)
    }
}

internal extension Vector3D {
    /// The unit vector in this direction, or zero for a zero vector
    var safelyNormalized: Vector3D {
        let length = magnitude
        return length > 0 ? self / length : .zero
    }
}
