import Testing
import Foundation
@testable import Cadova

/// The geometry used by the cross-process stability probe. A five-member union is enough for a
/// per-process hash seed to shuffle the children into a different order on every run.
@GeometryBuilder3D
private var probeGeometry: any Geometry3D {
    Union {
        Box(20)
        Cylinder(radius: 6, height: 40).translated(x: 4, y: 3, z: -10)
        Sphere(radius: 8).translated(x: 14, y: 14, z: 20)
        Cylinder(radius: 3, height: 50).translated(x: -5, y: 9, z: -5)
        Box([7, 30, 4]).translated(x: 2, y: -4, z: 11)
    }
}

/// A deliberately simple, self-contained FNV-1a used only by the probe, so that what it reports
/// depends on the mesh and nothing else.

/// A hand-built tree that exercises a union, a difference, transforms and a couple of primitives.
/// Built from the node factories directly so that its digest doesn't move when unrelated things,
/// such as a primitive's default segmentation, change.
private var referenceTree: GeometryNode<D3> {
    let body = GeometryNode<D3>.boolean([
        .shape(.box(size: [10, 20, 30])),
        .transform(.shape(.sphere(radius: 8, segmentCount: 24)), transform: .translation([1, 2, 3])),
        .transform(
            .shape(.cylinder(bottomRadius: 3, topRadius: 1, height: 12, segmentCount: 16)),
            transform: .translation([-4, 0, 5])
        ),
    ], type: .union)

    return .boolean([body, .shape(.box(size: [2, 2, 100]))], type: .difference)
}

@Suite struct StableNodeIdentityTests {
    // MARK: - Cross-process stability

    /// The decisive test. These digests were recorded once; they must come out identical in every
    /// process, on every platform, forever. If this fails after a change to the hashing code, the
    /// change broke identity stability — every cached result and every recorded golden file was
    /// computed against these numbers.
    @Test func `node digests match their recorded values`() {
        #expect(GeometryNode<D3>.shape(.box(size: [10, 20, 30])).digest.description
                == "51109e8bd513ca9932ef37a39faef96e")
        #expect(GeometryNode<D2>.shape(.circle(radius: 4, segmentCount: 32)).digest.description
                == "3e8ab4ac1eb11eeee0f6dc5be7ba184c")
        #expect(GeometryNode<D3>.empty.digest.description
                == "abda8f5b62cf5d47ec2a186782650355")
        #expect(referenceTree.digest.description
                == "6250bf80b02995b3597292326cab4660")
    }

    /// A union's canonical child order comes from the children's digests, so writing the same
    /// members in a different order has to produce not just an equal node but an identical one.
    @Test func `union children reach the same canonical order from any source order`() {
        let members: [GeometryNode<D3>] = [
            .shape(.box(size: [10, 20, 30])),
            .shape(.sphere(radius: 8, segmentCount: 24)),
            .shape(.cylinder(bottomRadius: 3, topRadius: 1, height: 12, segmentCount: 16)),
            .transform(.shape(.box(size: [1, 1, 1])), transform: .translation([5, 0, 0])),
            .shape(.box(size: [7, 30, 4])),
        ]

        let canonical = GeometryNode.boolean(members, type: .union)
        guard case .boolean(let canonicalChildren, _) = canonical.contents else {
            Issue.record("Expected a boolean node")
            return
        }

        for permutation in [members.reversed().map { $0 }, members.shuffled(), members.shuffled()] {
            let node = GeometryNode.boolean(permutation, type: .union)
            #expect(node.digest == canonical.digest)
            guard case .boolean(let children, _) = node.contents else {
                Issue.record("Expected a boolean node")
                return
            }
            #expect(children.map(\.digest) == canonicalChildren.map(\.digest))
        }
    }

    /// The digest is pinned to a recorded value. That value was recorded in a different process
    /// from the one asserting it, which is exactly the property under test: before this change the
    /// same model produced a different number in every run, and the union factory sorted its
    /// children by it.
    @Test func `the same model digests identically in a fresh process`() async throws {
        let context = _EvaluationContext()
        let node = try await context
            .buildResult(for: probeGeometry.withDefaultSegmentation(), in: .defaultEnvironment).node

        #expect(node.digest.description == "e2f376b9e5b35cd448f30085c6507f6e")
    }

    // MARK: - Digest agrees with equality

    @Test func `equal nodes have equal digests and unequal nodes do not`() {
        let nodes: [GeometryNode<D3>] = [
            .empty,
            .shape(.box(size: [10, 20, 30])),
            .shape(.box(size: [10, 20, 30.0000001])),
            .shape(.sphere(radius: 8, segmentCount: 24)),
            .shape(.sphere(radius: 8, segmentCount: 25)),
            .transform(.shape(.box(size: [10, 20, 30])), transform: .translation([1, 0, 0])),
            .transform(.shape(.box(size: [10, 20, 30])), transform: .translation([0, 1, 0])),
            .convexHull(.shape(.box(size: [10, 20, 30]))),
            .boolean([.shape(.box(size: [1, 1, 1])), .shape(.sphere(radius: 1, segmentCount: 8))], type: .union),
            .boolean([.shape(.box(size: [1, 1, 1])), .shape(.sphere(radius: 1, segmentCount: 8))], type: .difference),
            .boolean([.shape(.sphere(radius: 1, segmentCount: 8)), .shape(.box(size: [1, 1, 1]))], type: .difference),
            referenceTree,
        ]

        // Rebuilt independently, so equality never gets to shortcut on shared storage.
        let rebuilt = nodes.map { node -> GeometryNode<D3> in
            try! JSONDecoder().decode(GeometryNode<D3>.self, from: JSONEncoder().encode(node))
        }

        for (i, a) in nodes.enumerated() {
            for (j, b) in rebuilt.enumerated() {
                #expect((a == b) == (a.digest == b.digest))
                #expect((a == b) == (i == j))
            }
        }
    }

    // MARK: - Double canonicalization

    /// `-0.0 == +0.0`, so they must digest the same or equal nodes would compare unequal.
    @Test func `negative zero digests the same as positive zero`() {
        #expect(StableDigest(-0.0) == StableDigest(0.0))
        #expect(GeometryNode<D3>.transform(.shape(.box(size: [1, 1, 1])), transform: .translation([-0.0, 0, 0]))
                == GeometryNode<D3>.transform(.shape(.box(size: [1, 1, 1])), transform: .translation([0.0, 0, 0])))
    }

    /// All NaN payloads collapse to one marker, which makes node identity reflexive even for a
    /// geometry that carries a NaN dimension. Without that, such a node could never hit its own
    /// cache entry, and the cache would grow without bound.
    @Test func `all NaNs digest alike so node identity stays reflexive`() {
        #expect(StableDigest(Double.nan) == StableDigest(-Double.nan))
        #expect(StableDigest(Double.nan) == StableDigest(Double.signalingNaN))
        #expect(StableDigest(Double.nan) != StableDigest(Double.infinity))

        let node = GeometryNode<D3>.shape(.sphere(radius: .nan, segmentCount: 8))
        #expect(node == node)
        #expect(node.digest == GeometryNode<D3>.shape(.sphere(radius: .nan, segmentCount: 8)).digest)
    }

    @Test func `infinities are distinct from each other and from finite values`() {
        #expect(StableDigest(Double.infinity) != StableDigest(-Double.infinity))
        #expect(StableDigest(Double.infinity) != StableDigest(Double.greatestFiniteMagnitude))
    }

    // MARK: - Round trip

    @Test func `factory-built 3D trees survive a coding round trip unchanged`() throws {
        let trees: [GeometryNode<D3>] = [
            .empty,
            referenceTree,
            .shape(.box(size: [10, 20, 30])),
            .convexHull(.shape(.sphere(radius: 5, segmentCount: 12))),
            .transform(.shape(.box(size: [1, 2, 3])), transform: .translation([4, 5, 6])),
            .refine(.shape(.box(size: [1, 2, 3])), maxEdgeLength: 0.5),
            .simplify(.shape(.box(size: [1, 2, 3])), tolerance: 0.01),
            .select(.decompose(.shape(.box(size: [1, 2, 3]))), index: 1),
            .applyMaterial(.shape(.box(size: [1, 2, 3])), material: .plain(.red)),
            .applyMaterial(.shape(.box(size: [1, 2, 3])), material: nil),
            .trim(.shape(.box(size: [1, 2, 3])), plane: Plane(offset: [0, 0, 1], normal: .up)),
            .smoothOut(.shape(.sphere(radius: 4, segmentCount: 16)), minSharpAngle: 30, minSmoothness: 0.5),
            .extrusion(.shape(.circle(radius: 3, segmentCount: 16)), type: .linear(height: 5)),
            .extrusion(.shape(.rectangle(size: [2, 3])), type: .rotational(angle: 180°, segments: 24)),
            .boolean([
                .shape(.box(size: [4, 4, 4])),
                .transform(.shape(.sphere(radius: 2, segmentCount: 12)), transform: .translation([1, 1, 1])),
            ], type: .intersection),
        ]

        for tree in trees {
            let decoded = try JSONDecoder().decode(GeometryNode<D3>.self, from: JSONEncoder().encode(tree))
            #expect(decoded == tree)
            #expect(decoded.digest == tree.digest)
        }
    }

    @Test func `factory-built 2D trees survive a coding round trip unchanged`() throws {
        let trees: [GeometryNode<D2>] = [
            .empty,
            .shape(.circle(radius: 4, segmentCount: 32)),
            .shape(.polygons(SimplePolygonList([SimplePolygon([[0, 0], [1, 0], [0, 1]])]), fillRule: .evenOdd)),
            .shape(.convexHull(points: [[0, 0], [3, 0], [1, 2]])),
            .offset(.shape(.circle(radius: 4, segmentCount: 32)),
                    amount: 1.5, joinStyle: .miter, miterLimit: 2, segmentCount: 12),
            .projection(.shape(.box(size: [1, 2, 3])), type: .slice(z: 1)),
            .projection(.shape(.box(size: [1, 2, 3])), type: .full),
            .transform(.shape(.rectangle(size: [3, 4])), transform: .translation([1, 2])),
            .boolean([
                .shape(.rectangle(size: [10, 5])),
                .shape(.circle(radius: 3, segmentCount: 24)),
            ], type: .union),
            .boolean([
                .shape(.rectangle(size: [10, 5])),
                .shape(.circle(radius: 3, segmentCount: 24)),
            ], type: .difference),
        ]

        for tree in trees {
            let decoded = try JSONDecoder().decode(GeometryNode<D2>.self, from: JSONEncoder().encode(tree))
            #expect(decoded == tree)
            #expect(decoded.digest == tree.digest)
        }
    }

    /// Decoding runs through the same normalizing factories as ordinary construction, so a payload
    /// holding shapes the factories would never produce — a nested union, a retained `.empty`, a
    /// transform of a transform — comes back normalized rather than as a tree that compares unequal
    /// to the same model built by hand.
    @Test func `decoding normalizes a payload the factories would never have produced`() throws {
        let box = GeometryNode<D3>.shape(.box(size: [10, 20, 30]))
        let sphere = GeometryNode<D3>.shape(.sphere(radius: 8, segmentCount: 24))
        let cylinder = GeometryNode<D3>.shape(.cylinder(bottomRadius: 3, topRadius: 1, height: 12, segmentCount: 16))

        // Built with the raw initializer, deliberately bypassing the factories.
        let denormalized = GeometryNode<D3>(.boolean([
            GeometryNode<D3>(.boolean([box, sphere], type: .union)),
            .empty,
            cylinder,
        ], type: .union))

        let decoded = try JSONDecoder().decode(
            GeometryNode<D3>.self, from: JSONEncoder().encode(denormalized)
        )

        #expect(decoded == GeometryNode.boolean([box, sphere, cylinder], type: .union))
        #expect(decoded != denormalized)

        let nestedTransform = GeometryNode<D3>(.transform(
            GeometryNode<D3>(.transform(box, transform: .translation([1, 0, 0]))),
            transform: .translation([0, 2, 0])
        ))
        let decodedTransform = try JSONDecoder().decode(
            GeometryNode<D3>.self, from: JSONEncoder().encode(nestedTransform)
        )
        #expect(decodedTransform == GeometryNode.transform(box, transform: .translation([1, 2, 0])))
    }

    /// The decoder used to re-sort union children by the current process's hash, which is what hid
    /// the instability: both sides of a comparison were shuffled the same way within one run.
    /// Now the encoded order is already canonical and decoding must preserve it verbatim.
    @Test func `decoding preserves the encoded union order`() throws {
        let node = referenceTree
        let decoded = try JSONDecoder().decode(GeometryNode<D3>.self, from: JSONEncoder().encode(node))

        guard case .boolean(let original, _) = node.contents,
              case .boolean(let roundTripped, _) = decoded.contents else {
            Issue.record("Expected boolean nodes")
            return
        }
        #expect(original.map(\.digest) == roundTripped.map(\.digest))
    }

    // MARK: - Cache probe cost

    /// A cache probe is a dictionary lookup on a node, and on a hit the old `==` fell through to a
    /// structural comparison of the whole subtree. That made every probe O(subtree) and, past a
    /// few hundred levels, overflowed the stack outright. Digest equality reads two words.
    @Test func `a cache probe on a very deep node does not walk it`() {
        func chain(depth: Int) -> GeometryNode<D3> {
            var node = GeometryNode<D3>.shape(.box(size: [10, 10, 10]))
            for i in 0..<depth {
                node = .convexHull(.transform(node, transform: .translation([Double(i) * 0.001, 0, 0])))
            }
            return node
        }

        let depth = 1000
        let table: [GeometryNode<D3>: Int] = [chain(depth: depth): 1]
        let probe = chain(depth: depth) // equal content, independently built storage
        #expect(table[probe] == 1)
    }

    // MARK: - Digest building blocks

    @Test func `the digest distinguishes structure, not just leaves`() {
        let a = GeometryNode<D3>.boolean([
            GeometryNode.boolean([.shape(.box(size: [1, 1, 1])), .shape(.box(size: [2, 2, 2]))], type: .difference),
            .shape(.box(size: [3, 3, 3])),
        ], type: .difference)

        let b = GeometryNode<D3>.boolean([
            .shape(.box(size: [1, 1, 1])),
            GeometryNode.boolean([.shape(.box(size: [2, 2, 2])), .shape(.box(size: [3, 3, 3]))], type: .difference),
        ], type: .difference)

        #expect(a.digest != b.digest)
    }

    @Test func `an imported mesh digests once and identically`() {
        let vertices: [Vector3D] = [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]]
        let faces: [MeshData.Face] = [[0, 2, 1], [0, 1, 3], [1, 2, 3], [2, 0, 3]]

        let first = MeshData(vertices: vertices, faces: faces)
        let second = MeshData(vertices: vertices, faces: faces)
        #expect(first.digest == second.digest)
        #expect(first == second)

        let different = MeshData(vertices: vertices, faces: [[0, 1, 2], [0, 1, 3], [1, 2, 3], [2, 0, 3]])
        #expect(different.digest != first.digest)
        #expect(different != first)
    }

    @Test func `a polygon list digests by content`() {
        let triangle = SimplePolygon([[0, 0], [1, 0], [0, 1]])
        let square = SimplePolygon([[0, 0], [1, 0], [1, 1], [0, 1]])

        #expect(SimplePolygonList([triangle, square]).digest == SimplePolygonList([triangle, square]).digest)
        #expect(SimplePolygonList([triangle, square]).digest != SimplePolygonList([square, triangle]).digest)

        // Assigning the array back is the only way to edit a list, and it re-derives the digest.
        var mutated = SimplePolygonList([triangle, square])
        mutated.polygons[0] = square
        #expect(mutated.digest == SimplePolygonList([square, square]).digest)
    }

    // MARK: - The hash construction itself

    /// The digest is SipHash-2-4 with a 128-bit output. Checking it against the published reference
    /// vectors is what makes "the same number in every process, on every platform" a claim about a
    /// specified function rather than about whatever this file happens to compute.
    ///
    /// The vectors are stated for the key `000102…0f`, and for inputs that are the first `n` bytes of
    /// `000102…`. Reference output is written as a byte string whose first eight bytes are `low`
    /// little-endian and whose last eight are `high`, which is the reverse of the order
    /// `description` prints them in.
    @Test(arguments: [
        (0, 0xe6a825ba047f81a3 as UInt64, 0x930255c71472f66d as UInt64),
        (1, 0x44af996bd8c187da as UInt64, 0x45fc229b11597634 as UInt64),
        (7, 0x53c1dbd8beebf1a1 as UInt64, 0x3982f01fa64ab8c0 as UInt64),
        (8, 0x61f55862baa9623b as UInt64, 0xb49714f364e2830f as UInt64),
        (15, 0x11a8b03399e99354 as UInt64, 0xd9c3cf970fec087e as UInt64),
    ])
    func `the hasher reproduces the published SipHash-2-4 reference vectors`(
        length: Int, low: UInt64, high: UInt64
    ) {
        var hasher = StableHasher(key0: 0x0706_0504_0302_0100, key1: 0x0f0e_0d0c_0b0a_0908)
        hasher.combine(bytes: (0..<UInt8(length)))
        let digest = hasher.finalize()

        #expect(digest.low == low)
        #expect(digest.high == high)
    }

    /// A one-bit change in the input has to scatter across the whole digest, or the collision bound
    /// that 128 bits buys is fiction. Over all 128 single-bit flips of a sixteen-byte input, the
    /// number of output bits that change averages 64.28 and never falls below 50.
    @Test func `a one-bit input change moves about half the output bits`() {
        func digest(of bytes: [UInt8]) -> StableDigest {
            var hasher = StableHasher()
            hasher.combine(bytes: bytes)
            return hasher.finalize()
        }

        let base = Array<UInt8>(0..<16)
        let reference = digest(of: base)

        let distances = (0..<(base.count * 8)).map { bit -> Int in
            var flipped = base
            flipped[bit / 8] ^= UInt8(1) << UInt8(bit % 8)
            let other = digest(of: flipped)
            return (other.low ^ reference.low).nonzeroBitCount
                + (other.high ^ reference.high).nonzeroBitCount
        }

        let mean = Double(distances.reduce(0, +)) / Double(distances.count)
        #expect(mean > 60 && mean < 68)
        #expect(distances.min()! > 40)
    }

    /// Everything reaches the hasher as explicit little-endian words, so a value's digest can't
    /// depend on the host's endianness or on the width of `Int`.
    @Test func `the hasher's primitive encodings match their recorded values`() {
        #expect(StableDigest(0).description == "f360a0dd0857a940979945db2d1b6bf4")
        #expect(StableDigest(1).description == "6450286b8c84def08ee0736651a75b23")
        #expect(StableDigest(1.0).description == "6abb0f7448779e026681c4b0a61e50fa")
        #expect(StableDigest("Cadova").description == "bc6d0e0aa0471f0ad9935b6ed4ca0702")
        #expect(StableDigest([1, 2, 3]).description == "52ae2addafee1f816e2fefadfaff4645")
    }
}
