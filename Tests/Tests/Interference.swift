import Foundation
import Testing
@testable import Cadova

struct InterferenceTests {
    private let left = Part("Left")
    private let middle = Part("Middle")
    private let far = Part("Far")

    /// Three 10 mm cubes: `middle` overlaps `left` by half its width, `far` touches nothing.
    private var assembly: any Geometry3D {
        Union {
            Box(10).inPart(left)
            Box(10).translated(x: 5).inPart(middle)
            Box(10).translated(x: 50).inPart(far)
        }
    }

    @Test func `overlapping parts are reported with the overlap volume`() async throws {
        let overlaps = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.interferences(among: assembly)
        }
        let overlap = try #require(overlaps.first)
        #expect(overlaps.count == 1)
        #expect(Set([overlap.first, overlap.second]) == [left, middle])
        #expect(overlap.volume ≈ 500)

        let measuredVolume = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.measurements(of: overlap.geometry).volume
        }
        #expect(measuredVolume ≈ 500)
    }

    @Test func `solid and context parts are checked by default, visual parts are not`() async throws {
        let bought = Part("Bought", semantic: .context)
        let guide = Part("Guide", semantic: .visual)
        let geometry = Union {
            Box(10).inPart(left)
            Box(10).translated(x: 5).inPart(bought)
            Box(10).translated(x: -5).inPart(guide)
        }
        let (byDefault, solidOnly, visualToo) = try await ModelFileGenerator.evaluate { evaluator in
            (
                await evaluator.interferences(among: geometry),
                await evaluator.interferences(among: geometry, including: [.solid]),
                await evaluator.interferences(among: geometry, including: [.solid, .visual])
            )
        }
        #expect(byDefault.count == 1)
        #expect(byDefault.first.map { Set([$0.first, $0.second]) } == [left, bought])
        #expect(solidOnly.isEmpty)
        #expect(visualToo.count == 1)
        #expect(visualToo.first.map { Set([$0.first, $0.second]) } == [left, guide])
    }

    @Test func `parts that only touch are not reported`() async throws {
        let overlaps = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.interferences(among: Union {
                Box(10).inPart(left)
                Box(10).translated(x: 10).inPart(middle)
            })
        }
        #expect(overlaps.isEmpty)
    }

    @Test func `ignored pairs match parts in either order`() async throws {
        let (forward, reversed) = try await ModelFileGenerator.evaluate { evaluator in
            (
                await evaluator.interferences(among: assembly, ignoring: [(left, middle)]),
                await evaluator.interferences(among: assembly, ignoring: [(middle, left)])
            )
        }
        #expect(forward.isEmpty)
        #expect(reversed.isEmpty)
    }

    @Test func `ignoring a part does not cover another part with the same name`() async throws {
        let impostor = Part("Middle")
        let overlaps = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.interferences(among: assembly, ignoring: [(left, impostor)])
        }
        #expect(overlaps.count == 1)
    }

    @Test func `overlaps smaller than the minimum volume are not reported`() async throws {
        let (lenient, strict) = try await ModelFileGenerator.evaluate { evaluator in
            (
                await evaluator.interferences(among: assembly, minimumVolume: 600),
                await evaluator.interferences(among: assembly, minimumVolume: 400)
            )
        }
        #expect(lenient.isEmpty)
        #expect(strict.count == 1)
    }

    @Test func `the main geometry is not checked against parts`() async throws {
        let overlaps = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.interferences(among: Union {
                Box(10)
                Box(10).translated(x: 5).inPart(middle)
            })
        }
        #expect(overlaps.isEmpty)
    }

    @Test func `keyed geometries are checked pairwise, largest overlap first`() async throws {
        let overlaps = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.interferences(among: [
                "base": Box(x: 30, y: 10, z: 10),
                "small": Box(10).translated(x: 28),      // 2 × 10 × 10 inside the base
                "large": Box(10).translated(x: -5),      // 5 × 10 × 10 inside the base
                "apart": Box(10).translated(z: 40),
            ] as [String: any Geometry3D])
        }
        try #require(overlaps.count == 2)
        let largest = overlaps[0]
        let smallest = overlaps[1]
        #expect(largest.volume ≈ 500)
        #expect(smallest.volume ≈ 200)
        #expect(Set([largest.first, largest.second]) == ["base", "large"])
        #expect(Set([smallest.first, smallest.second]) == ["base", "small"])
    }

    @Test func `keyed geometries honour ignored pairs`() async throws {
        let overlaps = try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.interferences(
                among: ["a": Box(10), "b": Box(10).translated(x: 5)] as [String: any Geometry3D],
                ignoring: [("b", "a")]
            )
        }
        #expect(overlaps.isEmpty)
    }
}
