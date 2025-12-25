import Foundation
import Testing
@testable import Cadova

struct RepeatAlongPathTests {
    // MARK: - 3D Repeat Along Path Tests

    @Test func `3D geometry repeated along straight path with count and spacing`() async throws {
        let path = BezierPath3D {
            line(x: 100)
        }

        let bounds = try await Sphere(diameter: 5)
            .repeated(along: path, count: 3, spacing: 20)
            .bounds

        // Spheres at x=0, x=20, x=40, each with radius 2.5
        #expect(bounds?.minimum.x ≈ -2.5)
        #expect(bounds?.maximum.x ≈ 42.5)
    }

    @Test func `3D geometry repeated along path with count only distributes evenly`() async throws {
        let path = BezierPath3D {
            line(x: 100)
        }

        let bounds = try await Box(5)
            .aligned(at: .center)
            .repeated(along: path, count: 3)
            .bounds

        // 3 boxes: at x=0, x=50, x=100
        #expect(bounds?.minimum.x ≈ -2.5)
        #expect(bounds?.maximum.x ≈ 102.5)
    }

    @Test func `3D geometry repeated along path with spacing only fills path`() async throws {
        let path = BezierPath3D {
            line(x: 60)
        }

        let bounds = try await Sphere(diameter: 4)
            .repeated(along: path, spacing: 20)
            .bounds

        // Path length 60, spacing 20: count = floor(60/20) = 3, spheres at 0, 20, 40
        #expect(bounds?.minimum.x ≈ -2)
        #expect(bounds?.maximum.x ≈ 42)
    }

    @Test func `3D geometry repeated along curved path`() async throws {
        // Quarter circle in XY plane
        let path = BezierPath3D {
            curve(controlX: 0, controlY: 50, controlZ: 0, endX: 50, endY: 50, endZ: 0)
        }

        let bounds = try await Box(5)
            .aligned(at: .center)
            .repeated(along: path, count: 2)
            .bounds

        // First box at start (0,0,0), second at end (50,50,0)
        #expect(bounds?.minimum.x ≈ -2.5)
        #expect(bounds?.maximum.x ≈ 52.5)
        #expect(bounds?.minimum.y ≈ -2.5)
        #expect(bounds?.maximum.y ≈ 52.5)
    }

    @Test func `3D geometry repeated along vertical path`() async throws {
        let path = BezierPath3D {
            line(z: 60)
        }

        let bounds = try await Box(x: 10, y: 10, z: 5)
            .aligned(at: .centerXY)
            .repeated(along: path, count: 3)
            .bounds

        // Boxes at z=0, z=30, z=60
        #expect(bounds?.minimum.z ≈ 0)
        #expect(bounds?.maximum.z ≈ 65)
    }

    // MARK: - 2D Repeat Along Path Tests

    @Test func `2D geometry repeated along straight path`() async throws {
        let path = BezierPath2D {
            line(x: 100)
        }

        let bounds = try await Circle(diameter: 10)
            .repeated(along: path, count: 3, spacing: 30)
            .bounds

        // Circles at x=0, x=30, x=60
        #expect(bounds?.minimum.x ≈ -5)
        #expect(bounds?.maximum.x ≈ 65)
    }

    @Test func `2D geometry repeated along path without rotation`() async throws {
        let path = BezierPath2D {
            line(y: 50)
        }

        // Rectangle that's wider than tall
        let bounds = try await Rectangle(x: 20, y: 5)
            .aligned(at: .center)
            .repeated(along: path, rotating: false, count: 2, spacing: 50)
            .bounds

        // Without rotation, rectangles stay 20x5 at y=0 and y=50
        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.minimum.y ≈ -2.5)
        #expect(bounds?.maximum.y ≈ 52.5)
    }
}
