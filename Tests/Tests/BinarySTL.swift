import Foundation
import Testing
@testable import Cadova

struct BinarySTLTests {
    /// A deterministic solid whose corners are jittered off the axis-aligned grid, so that every
    /// face has an oblique normal and every coordinate is a negative or fractional value. That
    /// exercises the encoder's float conversion far better than a plain box, whose normals are all
    /// ±1 and 0. The vertices are given literally rather than derived from a boolean or a curve, so
    /// the mesh depends on no trigonometry and no kernel arithmetic beyond copying the values
    /// through, which keeps the byte-level fixture stable across platforms.
    ///
    /// The literal mesh matters for a second reason: a mesh that comes out of a boolean is stable
    /// within a process but not between processes — the same union encodes to one of two byte
    /// sequences from run to run, differing by a cyclic rotation of some triangles' corners. A
    /// fixture built on one would be flaky. This one is stable.
    static let referenceCorners = [
        Vector3D(-5.5, -3.25, -2.125), // 0
        Vector3D(6.25, -4.75, -1.5),   // 1
        Vector3D(4.75, 5.3, -2.75),    // 2
        Vector3D(-6, 3.75, -1.25),     // 3
        Vector3D(-4.25, -2.5, 7.5),    // 4
        Vector3D(5.75, -3.5, 6.25),    // 5
        Vector3D(6.35, 4.25, 8.125),   // 6
        Vector3D(-5.25, 4.5, 6.75)     // 7
    ]

    static var referenceSolid: any Geometry3D {
        let corners = referenceCorners
        let faces = [
            [0, 3, 2], [0, 2, 1], // Bottom
            [4, 5, 6], [4, 6, 7], // Top
            [0, 1, 5], [0, 5, 4], // Front
            [1, 2, 6], [1, 6, 5], // Right
            [2, 3, 7], [2, 7, 6], // Back
            [3, 0, 4], [3, 4, 7]  // Left
        ]

        return Mesh(faces: faces.map { $0.map { corners[$0] } }, name: "BinarySTLTests.referenceSolid")
    }

    static let referenceFixtureName = "stl-encoder-reference"

    /// Encodes a geometry exactly the way `Model` does when writing an `.stl` file.
    static func encode(_ geometry: any Geometry3D, options: ModelOptions = []) async throws -> Data {
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        return try await BinarySTLDataProvider(result: result, options: options).generateOutput(context: context)
    }

    /// The bytes the STL prologue reserves for the model name: the first 80 bytes, up to the first
    /// null. The encoder replaces newlines with nulls, so this is the title line on its own.
    static func headerTitle(of data: Data) -> String? {
        String(data: Data(data.prefix(80).prefix { $0 != 0 }), encoding: .utf8)
    }

    // MARK: - Byte-level regression

    /// Locks the encoder's output down byte for byte against a checked-in fixture.
    ///
    /// A fixture rather than a hash: when this fails, the bytes are there to diff, and the failure
    /// message can point at the offset that moved. Regenerate with
    /// `CADOVA_REGENERATE_STL_FIXTURE=1 swift test --filter BinarySTLTests` — but only after
    /// confirming that a change to the encoded bytes is actually intended, since that is exactly
    /// what this test exists to catch.
    @Test func `binary STL encoding is byte-for-byte stable`() async throws {
        let data = try await Self.encode(Self.referenceSolid)

        if ProcessInfo.processInfo.environment["CADOVA_REGENERATE_STL_FIXTURE"] != nil {
            let resources = URL(filePath: #filePath)
                .deletingLastPathComponent()
                .appending(path: "resources")
                .appending(component: Self.referenceFixtureName)
                .appendingPathExtension("stl")
            try data.write(to: resources)
            return
        }

        let fixtureURL = try #require(Bundle.module.url(
            forResource: Self.referenceFixtureName, withExtension: "stl", subdirectory: "resources"
        ))
        let expected = try Data(contentsOf: fixtureURL)

        #expect(data.count == expected.count)
        if let offset = zip(data, expected).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset {
            Issue.record("STL output differs from the fixture at byte \(offset)")
        }
        #expect(data == expected)
    }

    /// The scalar layout the fixture encodes, spelled out independently of the encoder: sizes,
    /// offsets and little-endian byte order. STL is little-endian regardless of the host, so these
    /// are decoded a byte at a time rather than by loading integers in host order.
    @Test func `binary STL layout is little-endian with 50-byte triangle records`() async throws {
        let data = try await Self.encode(Self.referenceSolid)

        func littleEndianUInt32(at offset: Int) -> UInt32 {
            (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[offset + $1]) << (8 * $1) }
        }

        func littleEndianFloat(at offset: Int) -> Float32 {
            Float32(bitPattern: littleEndianUInt32(at: offset))
        }

        let triangleCount = Int(littleEndianUInt32(at: 80))
        #expect(triangleCount == 12)
        #expect(data.count == 84 + triangleCount * 50)

        // Every vertex written is one of the solid's corners, rounded to single precision, and
        // every corner appears. The kernel is free to reorder triangles and vertices, so this
        // checks the set rather than a particular position.
        let expectedCorners = Set(Self.referenceCorners.map { [Float32($0.x), Float32($0.y), Float32($0.z)] })
        var writtenCorners: Set<[Float32]> = []

        // Every record's normal is a unit vector, and every attribute word is zero.
        for index in 0..<triangleCount {
            let record = 84 + index * 50
            let normal = Vector3D(
                Double(littleEndianFloat(at: record)),
                Double(littleEndianFloat(at: record + 4)),
                Double(littleEndianFloat(at: record + 8))
            )
            #expect(abs(normal.magnitude - 1) < 1e-6)

            for vertex in 0..<3 {
                let offset = record + 12 + vertex * 12
                writtenCorners.insert((0..<3).map { littleEndianFloat(at: offset + $0 * 4) })
            }

            #expect(data[record + 48] == 0)
            #expect(data[record + 49] == 0)
        }

        #expect(writtenCorners == expectedCorners)
    }

    // MARK: - Round trip

    @Test func `encoded STL reimports with the same geometry`() async throws {
        let geometry = Self.referenceSolid
        let expected = try await geometry.measurements

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).stl")
        defer { try? FileManager.default.removeItem(at: url) }
        try await Self.encode(geometry).write(to: url)

        let imported = try await Import(model: url).measurements
        #expect(imported.triangleCount == expected.triangleCount)
        #expect(imported.volume ≈ expected.volume)
        #expect(imported.surfaceArea ≈ expected.surfaceArea)
        #expect(imported.boundingBox ≈ expected.boundingBox)
    }

    // MARK: - Header

    @Test func `STL prologue carries the metadata title`() async throws {
        let data = try await Self.encode(Self.referenceSolid, options: .metadata(title: "Jittered box"))

        #expect(data.count >= 84)
        #expect(Self.headerTitle(of: data) == "Jittered box")
    }

    @Test func `STL prologue falls back to the model name`() async throws {
        let data = try await Self.encode(Self.referenceSolid)
        #expect(Self.headerTitle(of: data) == "Cadova model")
    }

    /// The prologue is a fixed 80 bytes, so a long title has to be cut. Cutting at 80 UTF-8 bytes
    /// can land in the middle of a multi-byte character and leave the header undecodable, so the
    /// cut has to fall on a character boundary. The title here places a four-byte emoji across the
    /// boundary: bytes 79 and 80 are its first two, and a naive cut keeps exactly those.
    @Test func `long header is truncated on a character boundary`() async throws {
        let prefix = String(repeating: "A", count: 78)
        let title = prefix + "🧊" + "tail"
        #expect(title.utf8.count > 80)
        #expect(Data(title.utf8.prefix(80)).count == 80)

        let data = try await Self.encode(Self.referenceSolid, options: .metadata(title: title))
        let header = data.prefix(80)

        #expect(header.count == 80)
        #expect(Self.headerTitle(of: data) == prefix)
        #expect(String(data: Data(header.prefix { $0 != 0 }), encoding: .utf8) != nil)
    }

    /// A multi-byte character that ends exactly on the boundary is kept whole; nothing is dropped
    /// just for being multi-byte.
    @Test func `header keeps a multi-byte character that ends on the boundary`() async throws {
        let title = String(repeating: "A", count: 76) + "🧊"
        #expect(title.utf8.count == 80)

        let data = try await Self.encode(Self.referenceSolid, options: .metadata(title: title))
        #expect(Self.headerTitle(of: data) == title)
    }
}
