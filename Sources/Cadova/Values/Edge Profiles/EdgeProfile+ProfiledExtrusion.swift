import Foundation
import Manifold3D

/// An extrusion with profiled top and/or bottom edges, built directly as one mesh.
///
/// Cutting a profile out of a plain extrusion leaves the boolean to resolve the seam where the
/// profile meets the wall, and that seam is the worst case a boolean can get: a fillet leaves the
/// wall tangentially, so the cutter's surface runs nearly coplanar with the wall for its first few
/// facets. Along a faceted curve the engine resolves that near-contact by cutting tiny facets
/// across the wall's triangles, which shows up as a creased line around the bottom of the fillet.
///
/// Building the whole solid as a stack of rings avoids the boolean entirely. Every ring is the
/// outline offset inward by the profile's depth at that height, and every ring keeps the outline's
/// own structure point for point, so the lowest ring of a profile *is* the top edge of the wall and
/// the two surfaces share their vertices exactly. That's also much faster than sweeping a tool and
/// subtracting it.
///
/// The rings are offset per vertex rather than computed by a general polygon offset, since that's
/// what keeps the correspondence: a convex corner moves along its miter, and a concave corner fans
/// out into an arc. That's an exact inward offset only while no part of the outline collapses
/// within the profile's depth, so the result is checked against a real erosion first, and shapes
/// that fail the check keep the cutting construction.
struct ProfiledExtrusion: Geometry3D {
    let shape: any Geometry2D
    let height: Double
    let topEdge: EdgeProfile?
    let bottomEdge: EdgeProfile?

    var body: any Geometry3D {
        @Environment(\.segmentation) var segmentation

        (topEdge?.profile ?? Empty()).readingConcrete { topSection in
            (bottomEdge?.profile ?? Empty()).readingConcrete { bottomSection in
                shape.readingConcrete { crossSection in
                    let polygons = crossSection.polygonList().polygons
                    let outline = polygons.map { ProfiledContour.removingDuplicates($0.vertices) }
                    let top = topEdge.map { _ in EdgeProfile.inwardDepthSamples(of: topSection.polygonList().polygons) }
                    let bottom = bottomEdge.map { _ in EdgeProfile.inwardDepthSamples(of: bottomSection.polygonList().polygons) }

                    if let levels = Self.levels(height: height, top: top, bottom: bottom),
                       let maxDepth = levels.map(\.depth).max(), maxDepth > 0,
                       let contours = ProfiledContour.contours(of: outline, depth: ProfiledContour.checkDepth(for: maxDepth), segmentation: segmentation)
                    {
                        shape.offset(amount: -ProfiledContour.checkDepth(for: maxDepth), style: .round).readingConcrete { erodedSection in
                            let eroded = erodedSection.polygonList().polygons
                            if EdgeProfile.erosionPreservesStructure(original: polygons, deepest: eroded),
                               ProfiledContour.matches(contours, erodedArea: erodedSection.area, depth: ProfiledContour.checkDepth(for: maxDepth))
                            {
                                Self.mesh(contours: contours, levels: levels)
                            } else {
                                fallback
                            }
                        }
                    } else {
                        fallback
                    }
                }
            }
        }
    }

    /// The cutting construction, for shapes and profiles the direct one can't describe.
    private var fallback: any Geometry3D {
        var geometry = shape.extruded(height: height)
        if let topEdge {
            geometry = geometry.cuttingEdgeProfile(topEdge, on: .top, offset: 0, allowsDirectConstruction: false)
        }
        if let bottomEdge {
            geometry = geometry.cuttingEdgeProfile(bottomEdge, on: .bottom, offset: 0, allowsDirectConstruction: false)
        }
        return geometry
    }

    /// The heights the rings sit at, from the bottom face up, with how far inward each ring is
    /// offset. Returns `nil` when a profile can't be described as an inward depth per height, or
    /// when the two profiles together don't fit within the extrusion's height.
    static func levels(
        height: Double,
        top: [(height: Double, depth: Double)]??,
        bottom: [(height: Double, depth: Double)]??
    ) -> [(z: Double, depth: Double)]? {
        // An absent profile is `nil`, an indescribable one is `.some(nil)`
        if case .some(.none) = top { return nil }
        if case .some(.none) = bottom { return nil }
        let top = top.flatMap { $0 } ?? []
        let bottom = bottom.flatMap { $0 } ?? []

        // The samples run from the profile's deep end, where it meets the wall, up to the edge
        // face, with heights from -size to 0. The top profile hangs down from the top face, and the
        // bottom one is mirrored up from the bottom face.
        let bottomLevels = bottom.reversed().map { (z: -$0.height, depth: $0.depth) }
        let topLevels = top.map { (z: height + $0.height, depth: $0.depth) }

        func snapped(_ levels: [(z: Double, depth: Double)]) -> [(z: Double, depth: Double)] {
            levels.map { (z: $0.z, depth: $0.depth < 1e-9 ? 0 : $0.depth) }
        }
        let lower = bottomLevels.isEmpty ? [(z: 0.0, depth: 0.0)] : bottomLevels
        let upper = topLevels.isEmpty ? [(z: height, depth: 0.0)] : topLevels
        guard let lowerTop = lower.last, let upperBottom = upper.first,
              lowerTop.z <= upperBottom.z + 1e-9
        else { return nil }

        var levels = snapped(lower)
        for level in snapped(upper) {
            if let last = levels.last, abs(last.z - level.z) < 1e-9 {
                // The profiles meet with no wall between them; only a shared ring at the wall
                // itself can merge, since two different depths at one height would be a ledge
                guard abs(last.depth - level.depth) < 1e-9 else { return nil }
                continue
            }
            levels.append(level)
        }
        guard levels.count >= 2 else { return nil }
        return levels
    }

    /// How close two points of the same corner may come before they're treated as one.
    private static let mergeDistance = 1e-4

    static func mesh(contours: [ProfiledContour], levels: [(z: Double, depth: Double)]) -> any Geometry3D {
        var points: [Vector3D] = []
        var faces: [[Int]] = []
        // ringIndices[level][contour][sample]
        var ringIndices: [[[Int]]] = []

        for level in levels {
            var levelIndices: [[Int]] = []
            for contour in contours {
                var indices: [Int] = []
                indices.reserveCapacity(contour.samples.count)
                // A concave corner's samples fan out from the corner, so near the wall they crowd
                // together, and at the wall itself they coincide. Samples of one corner closer than
                // `mergeDistance` to the last point placed for it share that point instead.
                var previous: (origin: Int, point: Vector2D, index: Int)? = nil
                for sample in contour.samples {
                    let point = sample.position + sample.direction * level.depth
                    if let previous, previous.origin == sample.origin,
                       (point - previous.point).magnitude < Self.mergeDistance {
                        indices.append(previous.index)
                        continue
                    }
                    previous = (sample.origin, point, points.count)
                    indices.append(points.count)
                    points.append(Vector3D(point.x, point.y, level.z))
                }
                levelIndices.append(indices)
            }
            ringIndices.append(levelIndices)
        }

        func addTriangle(_ a: Int, _ b: Int, _ c: Int) {
            guard a != b, b != c, a != c else { return }
            faces.append([a, b, c])
        }

        for levelIndex in 0..<(levels.count - 1) {
            for contourIndex in contours.indices {
                let lower = ringIndices[levelIndex][contourIndex]
                let upper = ringIndices[levelIndex + 1][contourIndex]
                for i in lower.indices {
                    let j = (i + 1) % lower.count
                    addTriangle(lower[i], lower[j], upper[j])
                    addTriangle(lower[i], upper[j], upper[i])
                }
            }
        }

        // Caps, triangulated from the end rings' own points so they share vertices with the walls
        for (levelIndex, isTop) in [(0, false), (levels.count - 1, true)] {
            let rings = ringIndices[levelIndex].map { indices in
                var ring: [Int] = []
                for index in indices where ring.last != index {
                    ring.append(index)
                }
                if ring.count > 1, ring.first == ring.last {
                    ring.removeLast()
                }
                return ring
            }
            let list = SimplePolygonList(rings.map { ring in SimplePolygon(ring.map { Vector2D(points[$0].x, points[$0].y) }) })
            for triangle in list.triangulated() {
                let a = rings[triangle.0.0][triangle.0.1]
                let b = rings[triangle.1.0][triangle.1.1]
                let c = rings[triangle.2.0][triangle.2.1]
                if isTop {
                    addTriangle(a, b, c)
                } else {
                    addTriangle(a, c, b)
                }
            }
        }

        let vertices = points
        return Mesh(faces: faces, name: "Cadova.ProfiledExtrusion", cacheParameters: [vertices.map(\.x), vertices.map(\.y), vertices.map(\.z)], faces) {
            vertices[$0]
        }
    }
}

/// One contour of an outline, expressed as the samples every ring of a profiled extrusion places a
/// point for. Material lies to the left of the contour, as it does for both outer contours and
/// holes in a polygon list.
struct ProfiledContour {
    struct Sample {
        /// The outline vertex this sample belongs to.
        let origin: Int
        let position: Vector2D
        /// How far, and which way, the sample moves per unit of inward depth.
        let direction: Vector2D
    }

    let samples: [Sample]

    /// The samples for every contour, or `nil` if any of them would fold through itself at
    /// `depth`, which happens where the outline curves more tightly than the profile is deep.
    /// Every sample sits on one of the given vertices at depth zero, so a ring built from these
    /// reproduces the outline's points exactly.
    static func contours(of outline: [[Vector2D]], depth: Double, segmentation: Segmentation) -> [ProfiledContour]? {
        var result: [ProfiledContour] = []
        for vertices in outline {
            guard let contour = ProfiledContour(vertices: vertices, depth: depth, segmentation: segmentation) else {
                return nil
            }
            result.append(contour)
        }
        return result
    }

    private init?(vertices: [Vector2D], depth: Double, segmentation: Segmentation) {
        guard vertices.count >= 3 else { return nil }

        let circleSegments = Double(segmentation.segmentCount(circleRadius: depth))
        var samples: [Sample] = []
        for index in vertices.indices {
            let vertex = vertices[index]
            let incomingEdge = vertex - vertices[wrap: index - 1]
            let outgoingEdge = vertices[wrap: index + 1] - vertex
            guard incomingEdge.magnitude > 1e-12, outgoingEdge.magnitude > 1e-12 else { return nil }
            let incoming = incomingEdge.normalized
            let outgoing = outgoingEdge.normalized
            let inwardIn = Vector2D(-incoming.y, incoming.x)
            let inwardOut = Vector2D(-outgoing.y, outgoing.x)
            let cross = incoming.x * outgoing.y - incoming.y * outgoing.x
            let turn = Foundation.atan2(cross, incoming ⋅ outgoing)

            // A concave corner turns right, and its inward offset is an arc around the corner. Where
            // the turn is too slight for the arc to need more than one segment, the miter is just as
            // good and keeps the point count down along a gently concave curve.
            let arcSegments = turn < 0 ? Int((circleSegments * -turn / (2 * .pi)).rounded()) : 0
            if arcSegments >= 2 {
                let startAngle = Foundation.atan2(inwardIn.y, inwardIn.x)
                for step in 0...arcSegments {
                    let angle = startAngle + turn * Double(step) / Double(arcSegments)
                    samples.append(Sample(origin: index, position: vertex, direction: Vector2D(Foundation.cos(angle), Foundation.sin(angle))))
                }
            } else {
                let bisector = inwardIn + inwardOut
                let length = bisector.magnitude
                guard length > 1e-9 else { return nil }
                let unit = bisector / length
                let alignment = unit ⋅ inwardIn
                guard alignment > 1e-6 else { return nil }
                samples.append(Sample(origin: index, position: vertex, direction: unit / alignment))
            }
        }

        // Each edge between two vertices has to keep running the same way at the deepest ring. The
        // ring is linear in depth, so an edge that hasn't flipped there hasn't flipped anywhere above
        // it either; one that has is where the offset collapses and the rings would cross.
        for index in samples.indices {
            let a = samples[index]
            let b = samples[(index + 1) % samples.count]
            guard a.origin != b.origin else { continue }
            let original = b.position - a.position
            let offset = (b.position + b.direction * depth) - (a.position + a.direction * depth)
            guard original ⋅ offset > 1e-9 * original.magnitude else { return nil }
        }

        self.samples = samples
    }

    static func removingDuplicates(_ vertices: [Vector2D]) -> [Vector2D] {
        var result: [Vector2D] = []
        for vertex in vertices where result.last.map({ ($0 - vertex).magnitude > 1e-9 }) ?? true {
            result.append(vertex)
        }
        if result.count > 1, (result[0] - result[result.count - 1]).magnitude <= 1e-9 {
            result.removeLast()
        }
        return result
    }

    /// How deep the rings are checked for validity, a little past the profile's own depth. Features
    /// that collapse exactly at the profile's depth, such as holes whose grown rings just touch, are
    /// still separate at that depth in the erosion's eyes but leave the rings with nothing between
    /// them, so the check asks for some clearance.
    static func checkDepth(for depth: Double) -> Double {
        depth + max(depth * 0.01, 1e-3)
    }

    /// The area of the contour's ring at `depth`, signed by orientation.
    func signedArea(depth: Double) -> Double {
        var sum = 0.0
        for index in samples.indices {
            let a = samples[index].position + samples[index].direction * depth
            let next = samples[(index + 1) % samples.count]
            let b = next.position + next.direction * depth
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    /// Whether the deepest rings agree with a real erosion of the outline. A contour that folded
    /// across a distant part of the outline, rather than its own neighbors, keeps every edge
    /// running forward but no longer encloses the area the erosion does.
    static func matches(_ contours: [ProfiledContour], erodedArea: Double, depth: Double) -> Bool {
        let ringArea = contours.map { $0.signedArea(depth: depth) }.reduce(0, +)
        let scale = max(abs(erodedArea), 1e-9)
        return abs(ringArea - erodedArea) / scale < 1e-4
    }
}

extension ProfiledContour {
    /// The boundary loops of the flat face at `z` that faces up, in the mesh's exact coordinates,
    /// with material to the left of each loop as for a polygon list. Returns `nil` if the face's
    /// boundary doesn't close into simple loops.
    static func boundaryLoops(ofTopFaceIn meshGL: MeshGL, at z: Double) -> [[Vector2D]]? {
        let vertices = meshGL.vertices
        // Vertices can be split for properties, so they're identified by position
        struct Key: Hashable { let x, y: Double }
        struct Edge: Hashable { let from, to: Key }
        var capEdges: Set<Edge> = []

        for triangle in meshGL.triangles {
            let a = vertices[triangle.a], b = vertices[triangle.b], c = vertices[triangle.c]
            guard abs(a.z - z) < 1e-9, abs(b.z - z) < 1e-9, abs(c.z - z) < 1e-9 else { continue }
            guard (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0 else { continue }
            let ka = Key(x: a.x, y: a.y), kb = Key(x: b.x, y: b.y), kc = Key(x: c.x, y: c.y)
            // An edge shared by two cap triangles appears once each way; inserting one direction
            // cancels the other, so only the face's boundary is left
            for edge in [Edge(from: ka, to: kb), Edge(from: kb, to: kc), Edge(from: kc, to: ka)] {
                if capEdges.remove(Edge(from: edge.to, to: edge.from)) == nil {
                    capEdges.insert(edge)
                }
            }
        }

        var next: [Key: Key] = [:]
        next.reserveCapacity(capEdges.count)
        for edge in capEdges {
            guard next.updateValue(edge.to, forKey: edge.from) == nil else { return nil }
        }

        var loops: [[Vector2D]] = []
        while let start = next.keys.first {
            var loop: [Vector2D] = []
            var current = start
            while let following = next.removeValue(forKey: current) {
                loop.append(Vector2D(current.x, current.y))
                current = following
                if current == start { break }
            }
            guard current == start, loop.count >= 3 else { return nil }
            loops.append(loop)
        }
        return loops.isEmpty ? nil : loops
    }
}
