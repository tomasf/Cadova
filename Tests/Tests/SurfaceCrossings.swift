import Testing
import Foundation
@testable import Cadova

struct SurfaceCrossingsTests {
    @Test func `segment through a unit box reports entry and exit`() async throws {
        let segment = LineSegment3D(from: [-1, 0.5, 0.5], to: [2, 0.5, 0.5])
        let geometry = Box(1)
            .readingSurfaces(along: segment) { box, crossings in
                box.adding {
                    for c in crossings {
                        Sphere(radius: 0.05).translated(c.position)
                    }
                }
            }
        // Expected: hits at x=0 (entry) and x=1 (exit). Spheres of radius 0.05 extend the bounds.
        #expect(try await geometry.bounds ≈ .init(minimum: [-0.05, 0, 0], maximum: [1.05, 1, 1]))
    }

    @Test func `ray from outside the box reports the same entry and exit`() async throws {
        let geometry = Box(1)
            .readingSurfaces(from: [-1, 0.5, 0.5], in: .right) { box, crossings in
                box.adding {
                    for c in crossings {
                        Sphere(radius: 0.05).translated(c.position)
                    }
                }
            }
        #expect(try await geometry.bounds ≈ .init(minimum: [-0.05, 0, 0], maximum: [1.05, 1, 1]))
    }

    @Test func `segment that misses the geometry produces no crossings`() async throws {
        let segment = LineSegment3D(from: [10, 10, 10], to: [20, 20, 20])
        let geometry = Box(1)
            .readingSurfaces(along: segment) { box, crossings in
                box.adding {
                    for c in crossings {
                        Sphere(radius: 5).translated(c.position)
                    }
                }
            }
        // No crossings → no spheres added → bounds equal the bare box.
        #expect(try await geometry.bounds ≈ .init(minimum: [0, 0, 0], maximum: [1, 1, 1]))
    }

    @Test func `first surface (ray) finds the box top in a peg drop`() async throws {
        // Ray from above box at z=10 going down should hit the top face at z=1.
        let geometry = Box(1)
            .readingFirstSurface(from: [0.5, 0.5, 10], in: .down) { box, hit in
                box.adding {
                    if let hit {
                        Sphere(radius: 0.05).translated(hit.position)
                    }
                }
            }
        // Top face of box is at z=1. Sphere extends to z=1.05.
        #expect(try await geometry.bounds ≈ .init(minimum: [0, 0, 0], maximum: [1, 1, 1.05]))
    }

    @Test func `first surface (segment) finds the same hit as the ray version`() async throws {
        let segment = LineSegment3D(from: [0.5, 0.5, 10], to: [0.5, 0.5, -1])
        let geometry = Box(1)
            .readingFirstSurface(along: segment) { box, hit in
                box.adding {
                    if let hit {
                        Sphere(radius: 0.05).translated(hit.position)
                    }
                }
            }
        #expect(try await geometry.bounds ≈ .init(minimum: [0, 0, 0], maximum: [1, 1, 1.05]))
    }

    @Test func `first surface ray miss produces no extra geometry`() async throws {
        let geometry = Box(1)
            .readingFirstSurface(from: [10, 10, 10], in: .up) { box, hit in
                box.adding {
                    if let hit {
                        // Should not run.
                        Sphere(radius: 5).translated(hit.position)
                    }
                }
            }
        #expect(try await geometry.bounds ≈ .init(minimum: [0, 0, 0], maximum: [1, 1, 1]))
    }

    @Test func `first surface segment miss produces no extra geometry`() async throws {
        let segment = LineSegment3D(from: [10, 10, 10], to: [20, 20, 20])
        let geometry = Box(1)
            .readingFirstSurface(along: segment) { box, hit in
                box.adding {
                    if let hit {
                        Sphere(radius: 5).translated(hit.position)
                    }
                }
            }
        #expect(try await geometry.bounds ≈ .init(minimum: [0, 0, 0], maximum: [1, 1, 1]))
    }

    @Test func `transition alternates as ray pierces a hollow shape`() async throws {
        // Outer 10×10×10 box centered at origin with a 6×6×6 cavity carved out of the middle.
        // A ray along +X through the center should hit: outer enter, outer exit-into-cavity,
        // inner enter, inner exit — transition pattern entering, exiting, entering, exiting.
        let shell = Box(10).aligned(at: .center)
            .subtracting {
                Box(6).aligned(at: .center)
            }

        // Encode (index, transition) into a unique sphere z-coordinate per crossing so the
        // overall z-extent of the result uniquely identifies the full sequence.
        // z = (index + 1) × (entering ? +100 : -100), writing entering as T and exiting as F:
        //   T, F, T, F  →  100, -200, 300, -400   → z bounds [-400, 300]
        //   T, T, T, T  →  100,  200, 300,  400   → z bounds [-5 (shell), 400]
        //   F, F, F, F  → -100, -200,-300, -400   → z bounds [-400, 5 (shell)]
        // The expected pattern T, F, T, F yields a unique min/max combination.
        let geometry = shell.readingSurfaces(from: [-10, 0, 0], in: .right) { shape, crossings in
            shape.adding {
                for (index, c) in crossings.enumerated() {
                    let z = Double(index + 1) * (c.transition == .entering ? 100 : -100)
                    Sphere(radius: 0.05).translated([c.position.x, 0, z])
                }
            }
        }
        let bounds = try await geometry.bounds
        // Max z = 300 + 0.05 (the +100 sphere at index 2). Min z = -400 - 0.05 (the -100 sphere at index 3).
        #expect(bounds?.maximum.z ≈ 300.05)
        #expect(bounds?.minimum.z ≈ -400.05)
    }

    // A 10×10×10 box centered at origin with a 6×6×6 cavity. Along +X through the center the wall
    // faces sit at x = -5 (entering), -3 (exiting), 3 (entering) and 5 (exiting).
    private var hollowShell: any Geometry3D {
        Box(10).aligned(at: .center)
            .subtracting {
                Box(6).aligned(at: .center)
            }
    }

    @Test func `first surface (ray) with a transition skips the nearer crossing`() async throws {
        // Only the marker sphere is returned, so its bounds pin down the crossing position exactly.
        let marker = hollowShell.readingFirstSurface(from: [-10, 0, 0], in: .right, transition: .exiting) { _, hit in
            if let hit {
                Sphere(radius: 0.05).translated(hit.position)
            }
        }
        // The nearest crossing is the entry at x = -5; .exiting skips it for the cavity wall at x = -3.
        #expect(try await marker.bounds ≈ .init(minimum: [-3.05, -0.05, -0.05], maximum: [-2.95, 0.05, 0.05]))
    }

    @Test func `first surface (ray) without a transition keeps the nearest crossing`() async throws {
        let marker = hollowShell.readingFirstSurface(from: [-10, 0, 0], in: .right) { _, hit in
            if let hit {
                Sphere(radius: 0.05).translated(hit.position)
            }
        }
        #expect(try await marker.bounds ≈ .init(minimum: [-5.05, -0.05, -0.05], maximum: [-4.95, 0.05, 0.05]))
    }

    @Test func `first surface (segment) with a transition skips the nearer crossing`() async throws {
        let segment = LineSegment3D(from: [-10, 0, 0], to: [10, 0, 0])
        let marker = hollowShell.readingFirstSurface(along: segment, transition: .exiting) { _, hit in
            if let hit {
                Sphere(radius: 0.05).translated(hit.position)
            }
        }
        #expect(try await marker.bounds ≈ .init(minimum: [-3.05, -0.05, -0.05], maximum: [-2.95, 0.05, 0.05]))
    }

    @Test func `first surface with an unmatched transition produces no crossing`() async throws {
        // A ray starting inside the far wall only ever exits, so .entering matches nothing.
        let geometry = hollowShell.readingFirstSurface(from: [4, 0, 0], in: .right, transition: .entering) { shell, hit in
            shell.adding {
                if let hit {
                    Sphere(radius: 5).translated(hit.position)
                }
            }
        }
        #expect(try await geometry.bounds ≈ .init(minimum: [-5, -5, -5], maximum: [5, 5, 5]))
    }
}
