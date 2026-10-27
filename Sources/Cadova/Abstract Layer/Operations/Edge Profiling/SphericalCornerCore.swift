import Foundation

/// The solid subtracted from a fillet corner patch's hull to round it, continuing the meeting
/// fillets exactly.
///
/// Each meeting tool ends in a ring whose arc lies on the corner sphere, and the patch hull
/// reaches `faceOvershoot` into each tool so the two overlap volumetrically. A plain `Sphere`
/// can't serve here: its own tessellation agrees with the tools' arcs at best on the ring
/// planes, and inside the overlap it keeps curving away from the tools' flat facets by a
/// fraction of a micrometer, leaving slivers and near-duplicate vertices wherever the patch
/// meets a tool. This solid is instead bounded by the tools' own arc points: a spherical
/// triangle spanning the three arcs, joined to the corner center, plus, for each tool, the
/// fan between the center and its arc carried into that tool along the tool's own facets.
///
internal struct SphericalCornerCore {
    struct Terminal {
        let arc: [Vector3D]        // the tool ring's curve points, on the sphere
        let intoChain: Vector3D    // unit direction from the corner into the tool
    }

    let center: Vector3D
    let radius: Double
    let terminals: [Terminal]
    let overshoot: Double  // how far the patch hull reaches into each tool

    /// How far the core reaches into each tool. Past the hull, so the core's end crosses the
    /// hull's end instead of lying in its plane, where rounding in a general orientation
    /// would leave a sliver between the two.
    private var reach: Double { overshoot * 2 }

    /// Returns the core solid, or nil if the arcs don't bound a spherical triangle.
    var geometry: (any Geometry3D)? {
        guard let loop = orderedTerminals() else { return nil }

        var faces = gridSurface(loop: loop) ?? sectorSurface(loop: loop)

        for terminal in loop {
            let arc = terminal.arc

            // The fan between the center and the arc, carried into the tool along its facets
            let offset = terminal.intoChain * reach
            let shiftedArc = arc.map { $0 + offset }
            let shiftedCenter = center + offset
            for column in 0..<(arc.count - 1) {
                faces.append(Self.oriented(
                    [arc[column], arc[column + 1], shiftedArc[column + 1], shiftedArc[column]],
                    outward: (arc[column] + arc[column + 1]) / 2 - center
                ))
                faces.append(Self.oriented(
                    [shiftedCenter, shiftedArc[column + 1], shiftedArc[column]], outward: terminal.intoChain
                ))
            }
        }

        // Where two tools' arcs meet at a face tangent point, both tools' carried fans border
        // on the radial line from the center to that point. The patch hull also covers the gap
        // between them, which belongs to the face, so fill it: the parallelepiped spanned by the
        // radial line and both tools' offsets, sharing its two inner sides with the fans' sides.
        for (index, corner) in loop.map({ $0.arc[0] }).enumerated() {
            let ownOffset = loop[index].intoChain * reach
            let otherOffset = loop[(index + loop.count - 1) % loop.count].intoChain * reach
            let bothOffsets = ownOffset + otherOffset
            let radial = corner - center
            faces += [
                Self.oriented(
                    [center + ownOffset, corner + ownOffset, corner + bothOffsets, center + bothOffsets],
                    outward: ownOffset
                ),
                Self.oriented(
                    [center + otherOffset, corner + otherOffset, corner + bothOffsets, center + bothOffsets],
                    outward: otherOffset
                ),
                Self.oriented([center, center + ownOffset, center + bothOffsets, center + otherOffset], outward: -radial),
                Self.oriented([corner, corner + ownOffset, corner + bothOffsets, corner + otherOffset], outward: radial),
            ]
        }

        return Mesh(
            faces: faces,
            name: "Cadova.SphericalCornerCore",
            cacheParameters: center, radius, loop.map(\.arc), loop.map(\.intoChain), overshoot
        )
    }

    /// The spherical triangle as a triangular grid: rows parallel to one arc, each spanning
    /// between the other two arcs' points at that distance, down to the opposite corner. The
    /// two side arcs must share a segment count; the first arc may differ, with row lengths
    /// shrinking proportionally. Returns nil if no arc can serve as the first.
    private func gridSurface(loop: [Terminal]) -> [[Vector3D]]? {
        // Rotate the loop so the arc whose count differs (if any) comes first
        guard let first = loop.indices.first(where: {
            loop[($0 + 1) % 3].arc.count == loop[($0 + 2) % 3].arc.count
        }) else { return nil }
        let (base, right, left) = (loop[first].arc, loop[(first + 1) % 3].arc, loop[(first + 2) % 3].arc)
        let baseCount = base.count - 1
        let rowCount = right.count - 1

        // Rows run around the opposite corner like circles of latitude, with angle and distance
        // from it interpolated between the row's ends. A great circle between the ends would
        // bow toward that corner when they're far apart, crowding the rows together.
        let apex = (right[rowCount] - center).normalized
        func rowPoint(from start: Vector3D, to end: Vector3D, fraction: Double) -> Vector3D {
            let (startPolar, endPolar) = (apex.angle(with: start), apex.angle(with: end))
            let startAzimuth = (start - apex * (start ⋅ apex)).normalized
            let endAzimuth = (end - apex * (end ⋅ apex)).normalized
            let turn = Angle(radians: atan2((startAzimuth × endAzimuth) ⋅ apex, startAzimuth ⋅ endAzimuth))
            let azimuth = startAzimuth * cos(turn * fraction) + (apex × startAzimuth) * sin(turn * fraction)
            let polar = startPolar + (endPolar - startPolar) * fraction
            return center + (apex * cos(polar) + azimuth * sin(polar)) * radius
        }

        let rows: [[Vector3D]] = (0...rowCount).map { row in
            if row == 0 { return base }
            let start = left[rowCount - row]   // from the base's start toward the opposite corner
            let end = right[row]               // from the base's end toward the opposite corner
            guard row < rowCount else { return [end] }
            let span = max(1, Int((Double(baseCount) * Double(rowCount - row) / Double(rowCount)).rounded()))
            let (from, to) = ((start - center).normalized, (end - center).normalized)
            let interior = (1..<span).map { rowPoint(from: from, to: to, fraction: Double($0) / Double(span)) }
            return [start] + interior + [end]
        }

        // Zip each pair of rows together, advancing along whichever row is behind
        var faces: [[Vector3D]] = []
        for row in 0..<rowCount {
            let (upper, lower) = (rows[row], rows[row + 1])
            let (upperCount, lowerCount) = (upper.count - 1, lower.count - 1)
            var (i, j) = (0, 0)
            while i < upperCount || j < lowerCount {
                let advanceUpper = j == lowerCount
                    || (i < upperCount && Double(i + 1) * Double(lowerCount) <= Double(j + 1) * Double(upperCount))
                if advanceUpper {
                    faces.append(Self.oriented([upper[i], upper[i + 1], lower[j]], outward: upper[i] - center))
                    i += 1
                } else {
                    faces.append(Self.oriented([upper[i], lower[j + 1], lower[j]], outward: upper[i] - center))
                    j += 1
                }
            }
        }
        return faces
    }

    /// The spherical triangle as three sectors, one per arc, in rows converging toward the
    /// middle direction, for corners whose three arcs all differ in segment count.
    private func sectorSurface(loop: [Terminal]) -> [[Vector3D]] {
        let corners = loop.map { $0.arc[0] }
        let cornerDirections = corners.map { ($0 - center).normalized }
        let middle = cornerDirections.reduce(Vector3D.zero, +).normalized
        let rowCount = max(1, ((loop.map { $0.arc.count - 1 }.max() ?? 1) + 1) / 2)

        func surfacePoint(from direction: Vector3D, row: Int) -> Vector3D {
            center + Self.slerp(direction, middle, fraction: Double(row) / Double(rowCount)) * radius
        }
        let middlePoint = center + middle * radius

        // Corner radial lines are shared by the two sectors meeting there, so compute them once
        let radials: [[Vector3D]] = corners.indices.map { index in
            [corners[index]] + (1..<rowCount).map { surfacePoint(from: cornerDirections[index], row: $0) }
        }

        var faces: [[Vector3D]] = []
        for (index, terminal) in loop.enumerated() {
            let arc = terminal.arc
            let next = (index + 1) % loop.count
            let rows: [[Vector3D]] = (0..<rowCount).map { row in
                if row == 0 { return arc }
                let interior = arc[1..<(arc.count - 1)].map {
                    surfacePoint(from: ($0 - center).normalized, row: row)
                }
                return [radials[index][row]] + interior + [radials[next][row]]
            }
            for row in 0..<rowCount {
                for column in 0..<(arc.count - 1) {
                    let (a, b) = (rows[row][column], rows[row][column + 1])
                    let outward = (a + b) / 2 - center
                    if row + 1 < rowCount {
                        let (c, d) = (rows[row + 1][column + 1], rows[row + 1][column])
                        faces.append(Self.oriented([a, b, c], outward: outward))
                        faces.append(Self.oriented([a, c, d], outward: outward))
                    } else {
                        faces.append(Self.oriented([a, b, middlePoint], outward: outward))
                    }
                }
            }
        }
        return faces
    }

    /// The face, wound so its normal points along the given outward direction. Faces are
    /// oriented individually because the mesh is only checked for its overall winding.
    private static func oriented(_ face: [Vector3D], outward: Vector3D) -> [Vector3D] {
        let normal = (face[1] - face[0]) × (face[2] - face[0])
        return normal ⋅ outward < 0 ? face.reversed() : face
    }

    /// Orients and orders the terminals' arcs into a closed loop, each arc starting where the
    /// previous one ends, with shared endpoints made identical.
    private func orderedTerminals() -> [Terminal]? {
        guard terminals.count == 3, terminals.allSatisfy({ $0.arc.count >= 2 }) else { return nil }
        let tolerance = radius * 1e-6

        var remaining = terminals
        var loop = [remaining.removeFirst()]
        while !remaining.isEmpty, let joint = loop.last?.arc.last {
            guard let index = remaining.firstIndex(where: { terminal in
                [terminal.arc[0], terminal.arc[terminal.arc.count - 1]].contains { $0.distance(to: joint) < tolerance }
            }) else { return nil }

            let terminal = remaining.remove(at: index)
            var arc = terminal.arc[0].distance(to: joint) < tolerance ? terminal.arc : terminal.arc.reversed()
            arc[0] = joint
            loop.append(Terminal(arc: arc, intoChain: terminal.intoChain))
        }

        let start = loop[0].arc[0]
        guard let closing = loop.popLast(), let end = closing.arc.last, end.distance(to: start) < tolerance
        else { return nil }
        loop.append(Terminal(arc: closing.arc.dropLast() + [start], intoChain: closing.intoChain))
        return loop
    }

    private static func slerp(_ a: Vector3D, _ b: Vector3D, fraction: Double) -> Vector3D {
        let angle = a.angle(with: b)
        guard angle.radians > 1e-9 else { return a }
        let weightA = sin(angle * (1 - fraction)) / sin(angle)
        let weightB = sin(angle * fraction) / sin(angle)
        return a * weightA + b * weightB
    }
}
