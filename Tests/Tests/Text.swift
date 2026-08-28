import Foundation
import Testing
@testable import Cadova

struct TextTests {
    @Test func `text produces geometry with reasonable dimensions`() async throws {
        let text = Text("Hello tests!")
        let m = try await text.measurements
        let area = await m.area

        #expect(area > 100)
        #expect(m.boundingBox!.size.x > 50)
        #expect(m.boundingBox!.size.y > 8)
    }
}
