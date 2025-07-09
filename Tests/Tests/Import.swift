import Foundation
import Testing
@testable import Cadova

struct ImportTests {
    @Test func importCubeGears() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        try await Import(model: modelURL)
            .measuring { body, measurements in
                Empty() as D3.Geometry
                #expect(measurements.edgeCount == 38502)
                #expect(measurements.triangleCount == 25668)
            }
            .triggerEvaluation()

        try await Import(model: modelURL, parts: [.name("gear 1"), .name("gear 12")])
            .measuring { body, measurements in
                Empty() as D3.Geometry
                #expect(measurements.edgeCount == 7182)
                #expect(measurements.triangleCount == 4788)
            }
            .triggerEvaluation()
    }
}
