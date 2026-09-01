import Foundation
import Testing
@testable import Cadova

/// Sweeps over the count-based duplication operations and checks that each one emits exactly the
/// number of copies it was asked for.
///
/// Copies are counted at the node level rather than through `partCount`, because decomposition merges
/// copies that touch or coincide, which would hide a copy landing exactly on top of another one.
///
struct RepeatCountTests {
    // A fresh `_EvaluationContext` per call dominates the run time of a sweep, so the whole suite
    // shares one.
    let context = _EvaluationContext()

    static let sweep = 1...2000

    private static let listedMismatchLimit = 40

    private func expectNoMismatches(_ mismatches: [(requested: Int, emitted: Int)]) {
        var list = mismatches.prefix(Self.listedMismatchLimit)
            .map { "\($0.requested)→\($0.emitted)" }
            .joined(separator: ", ")
        if mismatches.count > Self.listedMismatchLimit {
            list += ", …(\(mismatches.count - Self.listedMismatchLimit) more)"
        }
        if !mismatches.isEmpty {
            Issue.record("\(mismatches.count) of \(Self.sweep.count) counts wrong: \(list)")
        }
    }

    // MARK: - Angular, half-open range

    @Test func repeatedInHalfOpenAngleRangeEmitsRequestedCount2D() async throws {
        var mismatches: [(requested: Int, emitted: Int)] = []
        for count in Self.sweep {
            let emitted = try await Circle(diameter: 2)
                .translated(x: 10)
                .repeated(in: 0°..<360°, count: count)
                .emittedCopyCount(in: context)
            if emitted != count { mismatches.append((count, emitted)) }
        }
        expectNoMismatches(mismatches)
    }

    @Test func repeatedInHalfOpenAngleRangeEmitsRequestedCount3D() async throws {
        var mismatches: [(requested: Int, emitted: Int)] = []
        for count in Self.sweep {
            let emitted = try await Box(2)
                .translated(x: 10)
                .repeated(around: .z, in: 0°..<360°, count: count)
                .emittedCopyCount(in: context)
            if emitted != count { mismatches.append((count, emitted)) }
        }
        expectNoMismatches(mismatches)
    }

    // MARK: - Angular, closed range

    @Test func repeatedInClosedAngleRangeEmitsRequestedCount2D() async throws {
        var mismatches: [(requested: Int, emitted: Int)] = []
        for count in Self.sweep {
            let emitted = try await Circle(diameter: 2)
                .translated(x: 10)
                .repeated(in: 0°...180°, count: count)
                .emittedCopyCount(in: context)
            if emitted != count { mismatches.append((count, emitted)) }
        }
        expectNoMismatches(mismatches)
    }

    @Test func repeatedInClosedAngleRangeEmitsRequestedCount3D() async throws {
        var mismatches: [(requested: Int, emitted: Int)] = []
        for count in Self.sweep {
            let emitted = try await Box(2)
                .translated(x: 10)
                .repeated(around: .z, in: 0°...180°, count: count)
                .emittedCopyCount(in: context)
            if emitted != count { mismatches.append((count, emitted)) }
        }
        expectNoMismatches(mismatches)
    }

    // MARK: - Linear

    @Test func repeatedAlongHalfOpenRangeEmitsRequestedCount() async throws {
        var mismatches: [(requested: Int, emitted: Int)] = []
        for count in Self.sweep {
            let emitted = try await Box(1)
                .repeated(along: .x, in: 0..<100, count: count)
                .emittedCopyCount(in: context)
            if emitted != count { mismatches.append((count, emitted)) }
        }
        expectNoMismatches(mismatches)
    }

    @Test func repeatedAlongClosedRangeEmitsRequestedCount() async throws {
        var mismatches: [(requested: Int, emitted: Int)] = []
        for count in Self.sweep {
            let emitted = try await Box(1)
                .repeated(along: .x, in: 0...100, count: count)
                .emittedCopyCount(in: context)
            if emitted != count { mismatches.append((count, emitted)) }
        }
        expectNoMismatches(mismatches)
    }

    // MARK: - The last copy in a closed range lands on the upper bound

    @Test func closedRangeLastCopyLandsExactlyOnUpperBound() async throws {
        // A step multiplied out `count - 1` times misses the upper bound by an ulp or two, which is
        // enough to drop the last copy entirely: 100 / 11 * 11 overshoots 100. The offsets are read
        // off the nodes because the measured bounds go through Manifold's single-precision
        // arithmetic, which rounds a miss this small away.
        let upperBound = 100.0
        let node = try await context.buildResult(
            for: Box(1).repeated(along: .x, in: 0...upperBound, count: 12).withDefaultSegmentation(),
            in: .defaultEnvironment
        ).node

        guard case .boolean(let children, type: .union) = node.contents else {
            Issue.record("Expected a union of copies")
            return
        }

        let offsets = children.compactMap { child -> Double? in
            guard case .transform(_, let transform) = child.contents else { return nil }
            return transform.offset.x
        }
        #expect(offsets.max() == upperBound)
    }

    // MARK: - Minimum spacing

    @Test func minimumSpacingKeepsTheSingleInstanceThatFits() async throws {
        // A 5 wide box in a range of 8 with a minimum spacing of 2: one instance fits, two don't.
        let geometry = Box(5).repeated(along: .x, in: 0...8, minimumSpacing: 2)
        #expect(try await geometry.emittedCopyCount(in: context) == 1)

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 5)
    }

    @Test func minimumSpacingCyclicallyKeepsTheSingleInstanceThatFits() async throws {
        let geometry = Box(5).repeated(along: .x, in: 0...8, minimumSpacing: 2, cyclically: true)
        #expect(try await geometry.emittedCopyCount(in: context) == 1)
    }

    @Test func minimumSpacingProducesNothingWhenTheGeometryDoesNotFit() async throws {
        let geometry = Box(5).repeated(along: .x, in: 0...4, minimumSpacing: 2)
        #expect(try await geometry.emittedCopyCount(in: context) == 0)
    }

    @Test func minimumSpacingSpansTheWholeRangeWhenSeveralFit() async throws {
        // A 5 wide box in a range of 50 with a minimum spacing of 3: available is 45, each further
        // instance costs 8, so 6 instances fit and the last one ends at the upper bound.
        let geometry = Box(5).repeated(along: .x, in: 0...50, minimumSpacing: 3)
        #expect(try await geometry.emittedCopyCount(in: context) == 6)

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 50)
    }

    // MARK: - Along a path with fixed spacing

    @Test func repeatedAlongPathWithSpacingIncludesTheInstanceAtTheEnd() async throws {
        let path = BezierPath3D {
            line(x: 10)
        }

        // Instances go at 0, 5 and 10; 10 does not exceed the path length.
        let geometry = Sphere(diameter: 2).repeated(along: path, spacing: 5)
        #expect(try await geometry.emittedCopyCount(in: context) == 3)

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ -1)
        #expect(bounds?.maximum.x ≈ 11)
    }

    @Test func repeatedAlongPathWithSpacingStopsBeforeExceedingTheLength() async throws {
        let path = BezierPath3D {
            line(x: 12)
        }

        // Instances go at 0, 5 and 10; 15 would exceed the path length.
        let geometry = Sphere(diameter: 2).repeated(along: path, spacing: 5)
        #expect(try await geometry.emittedCopyCount(in: context) == 3)
    }
}
