import Foundation
import Testing
@testable import Cadova

struct StadiumTests {
    @Test func horizontal() async throws {
        let s = Stadium([40, 12])
        let m = try await s.measurements

        #expect(m.area ≈ 449.074)
        #expect(s.area ≈ 449.097)
        #expect(m.boundingBox ≈ .init(minimum: [-20, -6], maximum: [20, 6]))
    }

    @Test func vertical() async throws {
        let s = Stadium([12, 40])
        let m = try await s.measurements

        #expect(m.area ≈ 449.074)
        #expect(s.area ≈ 449.097)
        #expect(m.boundingBox ≈ .init(minimum: [-6, -20], maximum: [6, 20]))
    }

    @Test func circular() async throws {
        let s = Stadium([12, 12])
        let m = try await s.measurements

        #expect(m.area ≈ 113.074)
        #expect(s.area ≈ 113.097)
        #expect(m.boundingBox ≈ .init(minimum: [-6, -6], maximum: [6, 6]))
    }

    @Test func nonIntegerSize() async throws {
        let s = Stadium([7.3, 2.1])
        let m = try await s.measurements

        #expect(m.area ≈ 14.371)
        #expect(s.area ≈ 14.384)
        #expect(m.boundingBox ≈ .init(minimum: [-3.647, -1.05], maximum: [3.65, 1.05]))
    }
}
