import Foundation

extension MeshDistanceField {
    /// Squared distance from a point to a node's box, zero inside
    func boxDistanceSquared(_ index: Int, _ x: Double, _ y: Double, _ z: Double) -> Double {
        let b = boxes.baseAddress! + 6 * index
        var total = 0.0
        if x < b[0] { total += (b[0] - x) * (b[0] - x) } else if x > b[3] { total += (x - b[3]) * (x - b[3]) }
        if y < b[1] { total += (b[1] - y) * (b[1] - y) } else if y > b[4] { total += (y - b[4]) * (y - b[4]) }
        if z < b[2] { total += (b[2] - z) * (b[2] - z) } else if z > b[5] { total += (z - b[5]) * (z - b[5]) }
        return total
    }

    /// The closest point on a face to (px, py, pz), in scalars: its squared distance, its position, and which feature
    /// it lies on (0 to 2: corners, 3 to 5: edges from corner k to k + 1, 6: the interior).
    /// Ericson, Real-Time Collision Detection 5.1.5.
    struct FacePoint {
        var distanceSquared: Double
        var x: Double, y: Double, z: Double
        var feature: Int
    }

    func facePoint(_ index: Int, _ px: Double, _ py: Double, _ pz: Double) -> FacePoint {
        let face = faces[index]
        let c = coordinates.baseAddress!
        return Self.facePoint(
            c[3 * face.0], c[3 * face.0 + 1], c[3 * face.0 + 2],
            c[3 * face.1], c[3 * face.1 + 1], c[3 * face.1 + 2],
            c[3 * face.2], c[3 * face.2 + 1], c[3 * face.2 + 2],
            px, py, pz
        )
    }

    /// The same for a face given by the coordinates of its corners
    @inline(__always)
    static func facePoint(
        _ ax: Double, _ ay: Double, _ az: Double, _ bx: Double, _ by: Double, _ bz: Double,
        _ cx: Double, _ cy: Double, _ cz: Double, _ px: Double, _ py: Double, _ pz: Double
    ) -> FacePoint {
        func result(_ x: Double, _ y: Double, _ z: Double, _ feature: Int) -> FacePoint {
            let dx = px - x, dy = py - y, dz = pz - z
            return FacePoint(distanceSquared: dx * dx + dy * dy + dz * dz, x: x, y: y, z: z, feature: feature)
        }
        let abx = bx - ax, aby = by - ay, abz = bz - az
        let acx = cx - ax, acy = cy - ay, acz = cz - az
        let apx = px - ax, apy = py - ay, apz = pz - az
        let d1 = abx * apx + aby * apy + abz * apz, d2 = acx * apx + acy * apy + acz * apz
        if d1 <= 0 && d2 <= 0 { return result(ax, ay, az, 0) }
        let bpx = px - bx, bpy = py - by, bpz = pz - bz
        let d3 = abx * bpx + aby * bpy + abz * bpz, d4 = acx * bpx + acy * bpy + acz * bpz
        if d3 >= 0 && d4 <= d3 { return result(bx, by, bz, 1) }
        let vc = d1 * d4 - d3 * d2
        // Each edge's squared length is the denominator of its parameter; one of zero length (two corners
        // coinciding) is its corner, which is where the point projects anyway
        if vc <= 0 && d1 >= 0 && d3 <= 0 {
            guard d1 - d3 > 0 else { return result(ax, ay, az, 0) }
            let t = d1 / (d1 - d3)
            return result(ax + abx * t, ay + aby * t, az + abz * t, 3)
        }
        let cpx = px - cx, cpy = py - cy, cpz = pz - cz
        let d5 = abx * cpx + aby * cpy + abz * cpz, d6 = acx * cpx + acy * cpy + acz * cpz
        if d6 >= 0 && d5 <= d6 { return result(cx, cy, cz, 2) }
        let vb = d5 * d2 - d1 * d6
        if vb <= 0 && d2 >= 0 && d6 <= 0 {
            guard d2 - d6 > 0 else { return result(ax, ay, az, 0) }
            let t = d2 / (d2 - d6)
            return result(ax + acx * t, ay + acy * t, az + acz * t, 5)
        }
        let va = d3 * d6 - d5 * d4
        if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
            guard (d4 - d3) + (d5 - d6) > 0 else { return result(bx, by, bz, 1) }
            let t = (d4 - d3) / ((d4 - d3) + (d5 - d6))
            return result(bx + (cx - bx) * t, by + (cy - by) * t, bz + (cz - bz) * t, 4)
        }
        // A degenerate triangle (all corners on a line) has no interior: the edges above have already covered it
        let sum = va + vb + vc
        guard sum > 0 else { return result(ax, ay, az, 0) }
        let denominator = 1 / sum
        let v = vb * denominator, w = vc * denominator
        return result(ax + abx * v + acx * w, ay + aby * v + acy * w, az + abz * v + acz * w, 6)
    }

    /// The full answer for a face point: its pseudonormal, and whether that can be trusted
    func closest(_ point: FacePoint, onFace index: Int) -> Closest {
        let face = faces[index]
        let reliable = reliableFeatures[index]
        let normal: Vector3D, isReliable: Bool
        switch point.feature {
        case 0: normal = vertexNormals[face.0]; isReliable = reliableVertices[face.0]
        case 1: normal = vertexNormals[face.1]; isReliable = reliableVertices[face.1]
        case 2: normal = vertexNormals[face.2]; isReliable = reliableVertices[face.2]
        case 3: normal = edgeNormals[index].0; isReliable = reliable & 2 != 0
        case 4: normal = edgeNormals[index].1; isReliable = reliable & 4 != 0
        case 5: normal = edgeNormals[index].2; isReliable = reliable & 8 != 0
        default: normal = faceNormals[index]; isReliable = reliable & 1 != 0
        }
        return Closest(distanceSquared: point.distanceSquared, point: Vector3D(point.x, point.y, point.z), pseudonormal: normal, face: index, isReliable: isReliable)
    }

    /// The closest point on one face, and the pseudonormal of the feature (face, edge or vertex) it lies on
    func closest(to p: Vector3D, onFace index: Int) -> Closest {
        closest(facePoint(index, p.x, p.y, p.z), onFace: index)
    }

    /// The closest point on the mesh. A hint, a face likely to be near (such as the answer for a nearby point),
    /// gives the search an early bound; the result is exact either way. With a limit, only points closer than it
    /// are looked for, which ends searches from far away much sooner; where there are none, the face is -1.
    func closest(to p: Vector3D, hint: Int? = nil, within limit: Double = .infinity) -> Closest {
        let none = Closest(distanceSquared: .infinity, point: .zero, pseudonormal: .zero, face: -1, isReliable: false)
        guard !nodes.isEmpty else { return none }
        let px = p.x, py = p.y, pz = p.z
        var best = FacePoint(distanceSquared: limit * limit, x: 0, y: 0, z: 0, feature: 0)
        var bestFace = -1
        if let hint, hint >= 0 {
            let candidate = facePoint(hint, px, py, pz)
            if candidate.distanceSquared < best.distanceSquared { best = candidate; bestFace = hint }
        }
        // Nodes to visit, with the squared distance to their boxes when they were queued: the bound may have
        // tightened since, ruling them out without a look
        let rootDistance = boxDistanceSquared(0, px, py, pz)
        if rootDistance < best.distanceSquared {
            let links = self.links.baseAddress!, childBoxes = self.childBoxes.baseAddress!
            let corners = orderedCorners.baseAddress!, order = self.order.baseAddress!
            withUnsafeTemporaryAllocation(of: Int32.self, capacity: 128) { stack in
            withUnsafeTemporaryAllocation(of: Double.self, capacity: 128) { bounds in
                var top = 1
                stack[0] = 0
                bounds[0] = rootDistance
                while top > 0 {
                    top -= 1
                    if bounds[top] >= best.distanceSquared { continue }
                    let index = Int(stack[top])
                    let first = Int(links[2 * index]), second = Int(links[2 * index + 1])
                    if first < 0 {
                        // Counted loops: range iteration is generic, and slow in unoptimized builds
                        var position = -1 - first
                        let end = position + second
                        while position < end {
                            let c = corners + 9 * position
                            let candidate = Self.facePoint(c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], px, py, pz)
                            if candidate.distanceSquared < best.distanceSquared { best = candidate; bestFace = order[position] }
                            position += 1
                        }
                        continue
                    }
                    // Written out rather than called: unoptimized builds don't inline, and this is the innermost loop
                    let box = childBoxes + 12 * index
                    var dl = 0.0, dr = 0.0
                    var lo = Double(box[0]), hi = Double(box[3])
                    if px < lo { dl += (lo - px) * (lo - px) } else if px > hi { dl += (px - hi) * (px - hi) }
                    lo = Double(box[1]); hi = Double(box[4])
                    if py < lo { dl += (lo - py) * (lo - py) } else if py > hi { dl += (py - hi) * (py - hi) }
                    lo = Double(box[2]); hi = Double(box[5])
                    if pz < lo { dl += (lo - pz) * (lo - pz) } else if pz > hi { dl += (pz - hi) * (pz - hi) }
                    lo = Double(box[6]); hi = Double(box[9])
                    if px < lo { dr += (lo - px) * (lo - px) } else if px > hi { dr += (px - hi) * (px - hi) }
                    lo = Double(box[7]); hi = Double(box[10])
                    if py < lo { dr += (lo - py) * (lo - py) } else if py > hi { dr += (py - hi) * (py - hi) }
                    lo = Double(box[8]); hi = Double(box[11])
                    if pz < lo { dr += (lo - pz) * (lo - pz) } else if pz > hi { dr += (pz - hi) * (pz - hi) }
                    // The nearer child on top, to be searched first
                    let (near, nearDistance, far, farDistance) = dl < dr ? (first, dl, second, dr) : (second, dr, first, dl)
                    if farDistance < best.distanceSquared { stack[top] = Int32(far); bounds[top] = farDistance; top += 1 }
                    if nearDistance < best.distanceSquared { stack[top] = Int32(near); bounds[top] = nearDistance; top += 1 }
                }
            }
            }
        }
        guard bestFace >= 0 else { return none }
        return closest(best, onFace: bestFace)
    }
}
