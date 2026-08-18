import Foundation
import Testing
@testable import CadovaLiveLink

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
            token: UUID(),
            path: "/tmp/example.3mf",
            parts: [
                LiveLinkMessage.Part(
                    name: "Body",
                    isPrintable: true,
                    transform: nil,
                    vertices: [0, 0, 0, 1, 0, 0, 0, 1, 0],
                    triangles: [0, 1, 2],
                    triangleMaterialIndices: [0],
                    defaultMaterialIndex: 0,
                    materials: [.init(color: .init(red: 255, green: 0, blue: 0, alpha: 255))]
                )
            ]
        )

        let frame = try LiveLinkFraming.makeFrame(for: message)
        let header = frame.prefix(LiveLinkFraming.headerSize)
        let payloadLength = try LiveLinkFraming.parseHeader(Data(header))
        let payload = frame.suffix(from: frame.startIndex + LiveLinkFraming.headerSize)
        #expect(payload.count == payloadLength)

        let decoded = try LiveLinkFraming.decodeMessage(Data(payload))
        #expect(decoded.token == message.token)
        #expect(decoded.path == message.path)
        #expect(decoded.parts.count == 1)
        #expect(decoded.parts[0].vertices == message.parts[0].vertices)
        #expect(decoded.parts[0].triangles == message.parts[0].triangles)
    }

    @Test func `rejects a header with the wrong magic`() {
        var bytes = [UInt8](repeating: 0, count: LiveLinkFraming.headerSize)
        bytes[3] = 1 // corrupt the magic
        #expect(throws: LiveLinkFraming.FramingError.self) {
            try LiveLinkFraming.parseHeader(Data(bytes))
        }
    }
}
