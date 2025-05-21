import Foundation
import Testing
@testable import Cadova

struct TextTests {
    @Test func testBasics() async throws {
        let text = Text("Hello tests!")
        let m = await text.measurements

        #expect(m.area > 100)
        #expect(m.boundingBox!.size.x > 50)
        #expect(m.boundingBox!.size.y > 8)
    }
}
