import Foundation
import Testing
import CadovaLiveLinkCore
import ThreeMF
@testable import Cadova

struct LiveLinkSettingsTests {
    @Test func `CADOVA_LIVELINK_DISABLED true disables pushing`() {
        #expect(LiveLinkSettings.defaultIsDisabled(environment: ["CADOVA_LIVELINK_DISABLED": "true"]))
        #expect(LiveLinkSettings.defaultIsDisabled(environment: ["CADOVA_LIVELINK_DISABLED": "1"]))
        #expect(LiveLinkSettings.defaultIsDisabled(environment: ["CADOVA_LIVELINK_DISABLED": "yes"]))
        #expect(LiveLinkSettings.defaultIsDisabled(environment: ["CADOVA_LIVELINK_DISABLED": "on"]))
    }

    @Test func `CADOVA_LIVELINK_DISABLED defaults to enabled`() {
        #expect(!LiveLinkSettings.defaultIsDisabled(environment: [:]))
        #expect(!LiveLinkSettings.defaultIsDisabled(environment: ["CADOVA_LIVELINK_DISABLED": "false"]))
        #expect(!LiveLinkSettings.defaultIsDisabled(environment: ["CADOVA_LIVELINK_DISABLED": "0"]))
    }
}

struct LiveLinkFramingTests {
    @Test func `round-trips a message through frame encode and decode`() throws {
        let message = LiveLinkMessage(
            buildUUID: UUID(),
            path: "/tmp/example.3mf",
            parts: [
                LiveLinkMessage.Part(
                    id: "body",
                    name: "Body",
                    semantic: "solid",
                    vertices: [0, 0, 0, 1, 0, 0, 0, 1, 0],
                    triangles: [0, 1, 2],
                    triangleMaterialIndices: [0],
                    defaultMaterialIndex: 0,
                    materials: [.init(color: .init(red: 255, green: 0, blue: 0, alpha: 255))]
                )
            ],
            metadata: .init(title: "Example")
        )

        let frame = try LiveLinkFraming.makeFrame(for: message)
        let header = frame.prefix(LiveLinkFraming.headerSize)
        let payloadLength = try LiveLinkFraming.parseHeader(Data(header))
        let payload = frame.suffix(from: frame.startIndex + LiveLinkFraming.headerSize)
        #expect(payload.count == payloadLength)

        let decoded = try LiveLinkFraming.decodeMessage(Data(payload))
        #expect(decoded.buildUUID == message.buildUUID)
        #expect(decoded.path == message.path)
        #expect(decoded.parts.count == 1)
        #expect(decoded.parts[0].id == message.parts[0].id)
        #expect(decoded.parts[0].vertices == message.parts[0].vertices)
        #expect(decoded.parts[0].triangles == message.parts[0].triangles)
        #expect(decoded.metadata.title == message.metadata.title)
    }

    @Test func `rejects a header with the wrong magic`() {
        var bytes = [UInt8](repeating: 0, count: LiveLinkFraming.headerSize)
        bytes[3] = 1 // corrupt the magic
        #expect(throws: LiveLinkFraming.FramingError.self) {
            try LiveLinkFraming.parseHeader(Data(bytes))
        }
    }
}

struct ThreeMFDataProviderLiveLinkTests {
    /// `Part.itemIndex` addresses a specific build item directly by position when rewriting the
    /// archive (e.g. for slicing a single part) — so a LiveLink push's part order has to agree with
    /// the 3MF file's `<item>` order, not just its evaluation order. Names are deliberately not
    /// alphabetical, since a model whose parts happen to evaluate in file order wouldn't catch a
    /// regression here.
    @Test func `LiveLink part order matches the 3MF build item order`() async throws {
        let geometry: any Geometry3D = Box(x: 10, y: 20, z: 30)
            .adding {
                Sphere(diameter: 5).translated(x: 20).inPart(Part("Zebra"))
                Sphere(diameter: 5).translated(x: -20).inPart(Part("Alpha"))
                Sphere(diameter: 5).translated(y: 20).inPart(Part("Mango"))
            }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).3mf")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = ThreeMFDataProvider(result: result, options: [])
        try await provider.writeOutput(to: tempURL, context: context)

        let reader = try ThreeMF.PackageReader(url: tempURL)
        let fileOrderIDs = try reader.model().build.items.map { $0.partNumber ?? "" }
        #expect(fileOrderIDs.count > 1)

        let resolved = try await provider.resolvedParts(context: context)
        let identifiers = ThreeMFDataProvider.fileIdentifiers(for: resolved)
        // Confirms this model actually exercises non-trivial reordering, rather than passing
        // vacuously because evaluation order already happened to match the file's sorted order.
        #expect(identifiers != fileOrderIDs)

        let liveLinkOrderIDs = zip(identifiers, resolved)
            .sorted { ThreeMFDataProvider.fileOrder($0.0, $1.0) }
            .map(\.0)

        #expect(liveLinkOrderIDs == fileOrderIDs)
    }
}
