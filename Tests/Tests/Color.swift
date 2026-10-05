import Foundation
import Testing
@testable import Cadova

struct ColorTests {
    @Test func `components outside zero to one are clamped`() {
        // As computed colors easily end up, just past the end of the range
        let color = Color(red: 1.0000001, green: -0.2, blue: 0.5, alpha: 2)
        #expect(color.red == 1)
        #expect(color.green == 0)
        #expect(color.blue == 0.5)
        #expect(color.alpha == 1)
    }
}
