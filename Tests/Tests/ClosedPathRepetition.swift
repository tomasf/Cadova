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
        // An open path's end is a real position, distinct from its start, so it keeps its final instance: a length
        // of 90 at spacing 45 places instances at 0, 45 and 90. (This used to expect 2, which only held because
        // adaptive sampling measured the path a little short of 90.)
        let open = try await Sphere(diameter: 2)
            .repeated(along: Self.square(side: 30, closed: false), spacing: 45)
            .emittedCopyCount(in: _EvaluationContext())
        #expect(open == 3)
    }

    @Test func `a single instance along a path is placed at its start`() async throws {
        let one = Sphere(diameter: 2).repeated(along: Self.square(side: 30, closed: false), count: 1)
        #expect(try await one.emittedCopyCount(in: _EvaluationContext()) == 1)
        let bounds = try #require(try await one.bounds)
        #expect(bounds.center ≈ [0, 0, 0])
    }

    @Test func `no instances along a path for a count of zero or less`() async throws {
        let path = Self.square(side: 30, closed: false)
        for count in [0, -3] {
            #expect(try await Sphere(diameter: 2).repeated(along: path, count: count).emittedCopyCount(in: _EvaluationContext()) == 0)
            #expect(try await Sphere(diameter: 2).repeated(along: path, count: count, spacing: 5).emittedCopyCount(in: _EvaluationContext()) == 0)
            let flat = BezierPath2D(linesBetween: [[0, 0], [30, 0], [30, 30]])
            #expect(try await Circle(diameter: 2).repeated(along: flat, count: count, spacing: 5).bounds == nil)
        }
    }
}
