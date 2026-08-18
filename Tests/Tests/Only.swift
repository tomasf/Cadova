import Foundation
import Testing
@testable import Cadova

struct OnlyTests {
    init() {
        Platform.revealingFilesDisabled = true
    }

    @Test func `only isolates geometry in local coordinates`() async throws {
        // The cylinder is translated, then only() is applied, then rotated
        // The rotation should be discarded, but the translation kept
        let geometry = Cylinder(diameter: 10, height: 20)
            .translated(z: 5)  // Inside only() - kept
            .only()
            .rotated(x: 90°)   // Outside only() - discarded

        let bounds = try await geometry.bounds

        // Without only(), bounds would be rotated (y-extent would be ~20)
        // With only(), the rotation is discarded, so z-extent should be 20
        #expect(bounds?.size.z ≈ 20)
        #expect(bounds?.minimum.z ≈ 5)
        #expect(bounds?.maximum.z ≈ 25)
    }

    @Test func `only discards geometry outside the marked subtree`() async throws {
        let geometry = Box(100)
            .subtracting {
                Cylinder(diameter: 10, height: 20)
                    .only()
            }

        let bounds = try await geometry.bounds

        // Only the cylinder should be present, not the box
        #expect(bounds?.size.x ≈ 10)
        #expect(bounds?.size.y ≈ 10)
        #expect(bounds?.size.z ≈ 20)
    }

    @Test func `only works with nested geometry`() async throws {
        let geometry = Box(100)
            .adding {
                Stack(.z) {
                    Box(10)
                    Sphere(diameter: 20)
                        .only()
                    Box(5)
                }
            }

        let bounds = try await geometry.bounds

        // Only the sphere should be present
        #expect(bounds?.size.x ≈ 20)
        #expect(bounds?.size.y ≈ 20)
        #expect(bounds?.size.z ≈ 20)
    }

    @Test func `only preserves internal transforms`() async throws {
        let geometry = Box(100)
            .subtracting {
                Union {
                    Box(10)
                        .translated(x: 20)  // This transform is inside the only() subtree
                }
                .only()
                .rotated(z: 45°)  // This transform is outside
            }

        let bounds = try await geometry.bounds

        // The box should be at x: 20...30, not rotated
        #expect(bounds?.minimum.x ≈ 20)
        #expect(bounds?.maximum.x ≈ 30)
    }

    @Test func `only isolates parts within the subtree`() async throws {
        let outerPart = Part("outer")
        let innerPart = Part("inner")

        let geometry = Box(100)
            .inPart(outerPart)
            .adding {
                Sphere(diameter: 20)
                    .inPart(innerPart)
                    .only()
            }

        let partNames = try await geometry.partNames

        // Only the inner part should be present
        #expect(partNames == ["inner"])
    }

    @Test func `without only all geometry is included`() async throws {
        // Control test to verify the geometry behaves normally without only()
        let geometry = Box(100)
            .subtracting {
                Cylinder(diameter: 10, height: 20)
            }

        let bounds = try await geometry.bounds

        // The full box (with cylinder subtracted) should be present
        #expect(bounds?.size.x ≈ 100)
        #expect(bounds?.size.y ≈ 100)
        #expect(bounds?.size.z ≈ 100)
    }
}
