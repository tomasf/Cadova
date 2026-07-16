import Testing
@testable import Cadova

struct MaterialTests {
    @Test func `colored geometry produces a material mapping`() async throws {
        let mapping = try await Box(10).colored(.red).node.evaluate(in: .init()).materialMapping
        #expect(mapping.isEmpty == false)
    }

    @Test func `withoutMaterials clears the material mapping`() async throws {
        let mapping = try await Box(10).colored(.red).withoutMaterials().node.evaluate(in: .init()).materialMapping
        #expect(mapping.isEmpty)
    }

    @Test func `withoutMaterials clears materials applied throughout the subtree`() async throws {
        let geometry = Box(10).colored(.red)
            .adding {
                Sphere(diameter: 5)
                    .colored(.blue)
                    .translated(x: 20)
            }
            .withoutMaterials()

        let mapping = try await geometry.node.evaluate(in: .init()).materialMapping
        #expect(mapping.isEmpty)
    }
}
