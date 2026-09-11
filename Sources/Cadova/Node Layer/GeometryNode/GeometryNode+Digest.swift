import Foundation

// The digest covers a node's contents, not its dimensionality: `GeometryNode<D2>.empty` and
// `GeometryNode<D3>.empty` carry the same digest. Nothing can confuse the two, because every cache
// and every comparison is generic over `D`, and `AnyCacheKey` folds in the key's dynamic type name,
// which differs between the two instantiations. Spending a word per node on a discriminant the type
// system already applies would buy nothing.
//
// A node's digest is computed once, in its initializer, from the digests its children already
// carry. Folding in a child's digest rather than walking the child means the cost of identifying a
// node is O(1) in the size of the subtree below it, and that a large imported mesh is hashed once
// where it enters the tree rather than again at every ancestor.

extension GeometryNode: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        hasher.combine(digest)
    }
}

extension GeometryNode.Contents: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .empty:
            hasher.combine(case: "empty")

        case .boolean(let children, let type):
            hasher.combine(case: "boolean")
            hasher.combine(type)
            hasher.combine(children)

        case .transform(let body, let transform):
            hasher.combine(case: "transform")
            hasher.combine(body)
            hasher.combine(transform: transform)

        case .convexHull(let body):
            hasher.combine(case: "convexHull")
            hasher.combine(body)

        case .refine(let body, let edgeLength):
            hasher.combine(case: "refine")
            hasher.combine(body)
            hasher.combine(edgeLength)

        case .simplify(let body, let tolerance):
            hasher.combine(case: "simplify")
            hasher.combine(body)
            hasher.combine(tolerance)

        case .select(let body, let index):
            hasher.combine(case: "select")
            hasher.combine(body)
            hasher.combine(index)

        case .decompose(let body):
            hasher.combine(case: "decompose")
            hasher.combine(body)

        case .materialized(let key):
            hasher.combine(case: "materialized")
            hasher.combine(key)

        case .shape2D(let shape):
            hasher.combine(case: "shape2D")
            hasher.combine(shape)

        case .offset(let body, let amount, let joinStyle, let miterLimit, let segmentCount):
            hasher.combine(case: "offset")
            hasher.combine(body)
            hasher.combine(amount)
            hasher.combine(joinStyle)
            hasher.combine(miterLimit)
            hasher.combine(segmentCount)

        case .projection(let body, let type):
            hasher.combine(case: "projection")
            hasher.combine(body)
            hasher.combine(type)

        case .shape3D(let shape):
            hasher.combine(case: "shape3D")
            hasher.combine(shape)

        case .applyMaterial(let body, let material):
            hasher.combine(case: "applyMaterial")
            hasher.combine(body)
            hasher.combine(material)

        case .extrusion(let body, let type):
            hasher.combine(case: "extrusion")
            hasher.combine(body)
            hasher.combine(type)

        case .trim(let body, let plane):
            hasher.combine(case: "trim")
            hasher.combine(body)
            hasher.combine(plane)

        case .smoothOut(let body, let minSharpAngle, let minSmoothness):
            hasher.combine(case: "smoothOut")
            hasher.combine(body)
            hasher.combine(minSharpAngle)
            hasher.combine(minSmoothness)
        }
    }
}

extension GeometryNode.Projection: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .full:
            hasher.combine(case: "full")
        case .slice(let z):
            hasher.combine(case: "slice")
            hasher.combine(z)
        }
    }
}

extension GeometryNode.Extrusion: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .linear(let height, let twist, let divisions, let scaleTop):
            hasher.combine(case: "linear")
            hasher.combine(height)
            hasher.combine(twist)
            hasher.combine(divisions)
            hasher.combine(scaleTop)
        case .rotational(let angle, let segments):
            hasher.combine(case: "rotational")
            hasher.combine(angle)
            hasher.combine(segments)
        }
    }
}

extension GeometryNode.PrimitiveShape2D: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .rectangle(let size):
            hasher.combine(case: "rectangle")
            hasher.combine(size)
        case .circle(let radius, let segmentCount):
            hasher.combine(case: "circle")
            hasher.combine(radius)
            hasher.combine(segmentCount)
        case .polygons(let list, let fillRule):
            hasher.combine(case: "polygons")
            hasher.combine(list)
            hasher.combine(fillRule)
        case .convexHull(let points):
            hasher.combine(case: "convexHull2D")
            hasher.combine(points)
        }
    }
}

extension GeometryNode.PrimitiveShape3D: StableHashable {
    func stableHash(into hasher: inout StableHasher) {
        switch self {
        case .box(let size):
            hasher.combine(case: "box")
            hasher.combine(size)
        case .sphere(let radius, let segmentCount):
            hasher.combine(case: "sphere")
            hasher.combine(radius)
            hasher.combine(segmentCount)
        case .cylinder(let bottomRadius, let topRadius, let height, let segmentCount):
            hasher.combine(case: "cylinder")
            hasher.combine(bottomRadius)
            hasher.combine(topRadius)
            hasher.combine(height)
            hasher.combine(segmentCount)
        case .convexHull(let points):
            hasher.combine(case: "convexHull3D")
            hasher.combine(points)
        case .mesh(let mesh):
            hasher.combine(case: "mesh")
            hasher.combine(mesh)
        }
    }
}
