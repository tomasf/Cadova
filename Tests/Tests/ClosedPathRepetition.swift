import Foundation
import Testing
@testable import Cadova

/// Repeating along a closed path must not place an instance at the seam on top of the one at distance 0.
struct ClosedPathRepetitionTests {
    private static func square(side: Double, closed: Bool) -> BezierPath3D {
        let path = BezierPath3D(startPoint: [0, 0, 0])
            .addingLine(to: [side, 0, 0])
            .addingLine(to: [side, side, 0])
            .addingLine(to: [0, side, 0])
        return closed ? path.closed() : path
    }

    @Test func `a closed path reports itself as closed`() {
        #expect(Self.square(side: 30, closed: true).isClosed)
        #expect(Self.square(side: 30, closed: false).isClosed == false)
    }

    @Test func `repeating along a closed path does not duplicate the seam`() async throws {
        // Perimeter 120 at spacing 30 would put instances at 0, 30, 60, 90 and 120, but 120 is 0.
        let count = try await Sphere(diameter: 2)
            .repeated(along: Self.square(side: 30, closed: true), spacing: 30)
            .emittedCopyCount(in: _EvaluationContext())
        #expect(count == 4)
    }

    @Test func `a closed path that does not divide evenly keeps every instance`() async throws {
        // Perimeter 100 at spacing 30: instances at 0, 30, 60, 90. None lands on the seam.
        let count = try await Sphere(diameter: 2)
            .repeated(along: Self.square(side: 25, closed: true), spacing: 30)
            .emittedCopyCount(in: _EvaluationContext())
        #expect(count == 4)
    }

    @Test func `an open path still places an instance at its end`() async throws {
        // An open path's end is a real position, distinct from its start, so it keeps its final instance.
        let open = try await Sphere(diameter: 2)
            .repeated(along: Self.square(side: 30, closed: false), spacing: 45)
            .emittedCopyCount(in: _EvaluationContext())
        #expect(open == 2)
    }
}
