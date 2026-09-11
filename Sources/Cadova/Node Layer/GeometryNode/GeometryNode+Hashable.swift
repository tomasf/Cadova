import Foundation

// Node identity now rests entirely on the 128-bit digest each node computes in its initializer
// (see `GeometryNode+Digest.swift`), so `Contents` no longer needs an `Equatable`/`Hashable`
// conformance of its own. The deep recursive structural comparison that used to live here ran on
// every cache *hit*, making each probe O(subtree); digest equality makes it O(1).

extension GeometryNode.Projection {
    private enum Kind: String {
        case full, slice
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.full, .full): true
        case let (.slice(a), .slice(b)): a == b

        case (.full, _), (.slice, _): false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .full:
            hasher.combine(Kind.full)
        case .slice(let z):
            hasher.combine(Kind.slice)
            hasher.combine(z)
        }
    }
}

extension GeometryNode.Extrusion {
    private enum Kind: String {
        case linear, rotational
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.linear(h1, t1, d1, s1), .linear(h2, t2, d2, s2)):
            h1 == h2 && t1 == t2 && d1 == d2 && s1 == s2
        case let (.rotational(a1, s1), .rotational(a2, s2)):
            a1 == a2 && s1 == s2

        case (.linear, _), (.rotational, _): false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .linear(let height, let twist, let divisions, let scaleTop):
            hasher.combine(Kind.linear)
            hasher.combine(height)
            hasher.combine(twist)
            hasher.combine(divisions)
            hasher.combine(scaleTop)
        case .rotational(let angle, let segments):
            hasher.combine(Kind.rotational)
            hasher.combine(angle)
            hasher.combine(segments)
        }
    }
}

extension GeometryNode.PrimitiveShape2D {
    private enum Kind: String {
        case rectangle, circle, polygon, convexHull
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .rectangle(let size):
            hasher.combine(Kind.rectangle)
            hasher.combine(size)
        case .circle(let radius, let segments):
            hasher.combine(Kind.circle)
            hasher.combine(radius)
            hasher.combine(segments)
        case .polygons(let list, let fillRule):
            hasher.combine(Kind.polygon)
            hasher.combine(list)
            hasher.combine(fillRule)
        case .convexHull(let points):
            hasher.combine(Kind.convexHull)
            hasher.combine(points)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.rectangle(a), .rectangle(b)): a == b
        case let (.circle(ra, sa), .circle(rb, sb)): ra == rb && sa == sb
        case let (.polygons(la, fa), .polygons(lb, fb)): la == lb && fa == fb
        case let (.convexHull(pa), .convexHull(pb)): pa == pb

        case (.rectangle, _), (.circle, _), (.polygons, _), (.convexHull, _): false
        }
    }
}

extension GeometryNode.PrimitiveShape3D {
    private enum Kind: String {
        case box, sphere, cylinder, convexHull, mesh
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .box(let size):
            hasher.combine(Kind.box)
            hasher.combine(size)
        case .sphere(let radius, let segmentCount):
            hasher.combine(Kind.sphere)
            hasher.combine(radius)
            hasher.combine(segmentCount)
        case .cylinder(let bottomRadius, let topRadius, let height, let segmentCount):
            hasher.combine(Kind.cylinder)
            hasher.combine(bottomRadius)
            hasher.combine(topRadius)
            hasher.combine(height)
            hasher.combine(segmentCount)
        case .convexHull(let points):
            hasher.combine(Kind.convexHull)
            hasher.combine(points)
        case .mesh(let mesh):
            hasher.combine(Kind.mesh)
            hasher.combine(mesh)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.box(a), .box(b)): a == b
        case let (.sphere(ra, sa), .sphere(rb, sb)): ra == rb && sa == sb
        case let (.cylinder(ba, ta, ha, sa), .cylinder(bb, tb, hb, sb)):
            ba == bb && ta == tb && ha == hb && sa == sb
        case let (.convexHull(pa), .convexHull(pb)): pa == pb
        case let (.mesh(ma), .mesh(mb)): ma == mb

        case (.box, _), (.sphere, _), (.cylinder, _), (.convexHull, _), (.mesh, _): false
        }
    }
}
