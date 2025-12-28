import Testing
@testable import Cadova

struct PartTests {
    @Test func `parts are exported separately from main geometry`() async throws {
        try await Box(10)
            .adding {
                Sphere(diameter: 5)
                    .inPart(named: "separate")
            }
            .translated(y: 10)
            .expectEquals(goldenFile: "separatePart")
    }

    @Test func `nested parts survive evaluation`() async throws {
        let g = Box(10)
            .adding {
                Sphere(diameter: 10)
                    .inPart(named: "inner")
                    .adding {
                        Sphere(diameter: 5)
                    }
                    .inPart(named: "outer")
            }
            .translated(x: 10)

        let partNames = try await g.parts.map(\.key.name)
        #expect(Set(partNames) == ["inner", "outer"])
    }

    @Test func `parts with same name are merged`() async throws {
        let g = Box(10)
            .adding {
                Sphere(diameter: 5)
                    .inPart(named: "merged")
            }
            .subtracting {
                Box(x: 20, y: 4, z: 4)
                    .inPart(named: "merged")
            }

        let parts = try await g.parts
        let mergedPart = try #require(parts.first { $0.key.name == "merged" && $0.key.semantic == .solid })
        let concrete = try await mergedPart.value.node.evaluate(in: .init()).concrete
        #expect(BoundingBox3D(concrete.bounds) ≈ BoundingBox3D(minimum: [-2.5, -2.5, -2.5], maximum: [20, 4, 4]))
    }

    @Test func `part root operation is always addition`() async throws {
        try await Box(10)
            .subtracting {
                Sphere(diameter: 10)
                    .readingOperation { op in
                        #expect(op == .addition)
                    }
                    .inPart(named: "subtracted")
            }
            .triggerEvaluation()
    }

    @Test func `parts can be detached and reattached`() async throws {
        let measurements = try await Box(10)
            .readingPartNames { #expect($0.isEmpty) }
            .adding {
                Sphere(diameter: 12)
                    .withSegmentation(count: 10)
                    .inPart(named: "sphere")
            }
            .readingPartNames { #expect($0 == ["sphere"]) }
            .subtracting {
                Cylinder(diameter: 4, height: 20)
                    .inPart(named: "cylinder")
            }
            .readingPartNames { #expect($0 == ["sphere", "cylinder"]) }
            .detachingPart(named: "sphere") { geometry, part in
                geometry.adding {
                    part
                }
            }
            .readingPartNames { #expect($0 == ["cylinder"]) }
            .measurements(for: .mainPart)

        #expect(measurements.boundingBox ≈ .init(minimum: [-6, -6, -6], maximum: [10, 10, 10]))
        #expect(measurements.volume ≈ 1676.119)
        #expect(measurements.surfaceArea ≈ 882.572)
    }

    @Test func `measurement scopes correctly filter parts`() async throws {
        try await Sphere(diameter: 10)
            .adding {
                Box(10)
                    .inPart(named: "box")
                Box(20)
                    .inBackground()
            }
            .measuringBounds(scope: .mainPart) { g, bounds in
                g
                #expect(bounds ≈ .init(minimum: [-5, -5, -5], maximum: [5, 5, 5]))
            }
            .measuringBounds(scope: .allParts) { g, bounds in
                g
                #expect(bounds ≈ .init(minimum: [-5, -5, -5], maximum: [20, 20, 20]))
            }
            .measuringBounds { g, bounds in
                g
                #expect(bounds ≈ .init(minimum: [-5, -5, -5], maximum: [10, 10, 10]))
            }
            .triggerEvaluation()
    }

    @Test func `stack correctly handles children with parts`() async throws {
        let stack = Stack(.x) {
            Sphere(diameter: 10)
                .inPart(named: "sphere")
            Box(20)
                .inPart(named: "box")
            Cylinder(diameter: 10, height: 20)
                .inBackground()
            Circle(diameter: 5)
                .extruded(height: 30)
        }

        let solidMeasurements = try await stack.measurements
        #expect(solidMeasurements.boundingBox ≈ .init(minimum: [0, -5, -5], maximum: [35, 20, 30]))
    }

    @Test func `transformed geometry measures parts correctly`() async throws {
        let geometry = Box(1)
            .adding {
                Box(2)
                    .translated(x: 3, y: 5, z: 8)
                    .inPart(named: "foo")
                Sphere(diameter: 10)
                    .inBackground()
            }
            .translated(x: 3)
            .rotated(z: 90°)

        let measurements = try await geometry.measurements
        #expect(measurements.boundingBox ≈ .init(minimum: [-7, 3, 0], maximum: [0, 8, 10]))

        let measurementsMain = try await geometry.measurements(for: .mainPart)
        #expect(measurementsMain.boundingBox ≈ .init(minimum: [-1, 3, 0], maximum: [0, 4, 1]))
    }

    @Test func `parts can be subtracted from main geometry`() async throws {
        let geometry = Box(10)
            .adding {
                Box(4)
                    .inPart(named: "box")
                Cylinder(diameter: 3, height: 12)
                    .inPart(named: "test", type: .context)
            }
            .subtractingParts()

        #expect(try await geometry.measurements.volume ≈ 1000.0)
        #expect(try await geometry.mainModelMeasurements.volume ≈ (1000.0 - 64.0))
    }

    @Test func `detaching parts removes them from parts list`() async throws {
        let geometry = Box(10)
            .adding {
                Box(4)
                    .inPart(named: "box")
            }
            .detachingPart(named: "box") { base, part in
                Stack(.x) {
                    base
                    part
                }
            }

        #expect(try await geometry.partNames.isEmpty)
        #expect(try await geometry.mainModelMeasurements.volume ≈ 1064)
        #expect(try await geometry.measurements.volume ≈ 1064)
    }

    @Test func `modifyingParts transforms all parts`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "box1")
            Box(2)
                .inPart(named: "box2")
        }.modifyingParts { part, name in
            part.scaled(0.5)
        }

        #expect(try await geometry.partNames == ["box1", "box2"])
        #expect(try await geometry.mainModelMeasurements.volume ≈ 1000)
        #expect(try await geometry.measurements.volume ≈ 1009)
    }

    @Test func `modifyingPart transforms single named part`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "box1")
            Box(2)
                .inPart(named: "box2")
        }.modifyingPart(named: "box1") {
            $0.scaled(0.5)
        }

        #expect(try await geometry.partNames == ["box1", "box2"])
        #expect(try await geometry.mainModelMeasurements.volume ≈ 1000)
        #expect(try await geometry.measurements.volume ≈ 1016)
    }

    @Test func `removingParts removes all parts`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "box1")
            Box(2)
                .inPart(named: "box2")
        }.removingParts()

        #expect(try await geometry.partNames == [])
        #expect(try await geometry.mainModelMeasurements.volume ≈ 1000)
        #expect(try await geometry.measurements.volume ≈ 1000)
    }

    @Test func `removingPart removes single named part`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "box1")
            Box(2)
                .inPart(named: "box2")
        }.removingPart(named: "box1")

        #expect(try await geometry.partNames == ["box2"])
        #expect(try await geometry.mainModelMeasurements.volume ≈ 1000)
        #expect(try await geometry.measurements.volume ≈ 1008)
    }

    // MARK: - Part instance API tests

    @Test func `same Part instance merges geometry`() async throws {
        let myPart = Part("merged")

        let geometry = Box(10)
            .adding {
                Sphere(diameter: 5)
                    .inPart(myPart)
            }
            .subtracting {
                Box(x: 20, y: 4, z: 4)
                    .inPart(myPart)
            }

        let parts = try await geometry.parts
        #expect(parts.count == 1)
        let mergedPart = try #require(parts.first { $0.key.name == "merged" })
        let concrete = try await mergedPart.value.node.evaluate(in: .init()).concrete
        #expect(BoundingBox3D(concrete.bounds) ≈ BoundingBox3D(minimum: [-2.5, -2.5, -2.5], maximum: [20, 4, 4]))
    }

    @Test func `different Part instances with same name are separate`() async throws {
        let part1 = Part("box")
        let part2 = Part("box")

        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(part1)
            Box(2)
                .inPart(part2)
        }

        let parts = try await geometry.parts
        #expect(parts.count == 2)
        #expect(parts.keys.allSatisfy { $0.name == "box" })
    }

    @Test func `Part can be detached by instance`() async throws {
        let spherePart = Part("sphere")

        let geometry = Box(10)
            .adding {
                Sphere(diameter: 12)
                    .withSegmentation(count: 10)
                    .inPart(spherePart)
                Cylinder(diameter: 4, height: 20)
                    .inPart(named: "cylinder")
            }
            .detachingPart(spherePart) { base, part in
                base.adding { part }
            }

        #expect(try await geometry.partNames == ["cylinder"])
        #expect(try await geometry.mainModelMeasurements.volume ≈ 1676.119)
    }

    @Test func `Part can be modified by instance`() async throws {
        let boxPart = Part("box1")

        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(boxPart)
            Box(2)
                .inPart(named: "box2")
        }.modifyingPart(boxPart) {
            $0.scaled(0.5)
        }

        #expect(try await geometry.partNames == ["box1", "box2"])
        #expect(try await geometry.measurements.volume ≈ 1016)
    }

    @Test func `Part can be removed by instance`() async throws {
        let boxPart = Part("box1")

        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(boxPart)
            Box(2)
                .inPart(named: "box2")
        }.removingPart(boxPart)

        #expect(try await geometry.partNames == ["box2"])
        #expect(try await geometry.measurements.volume ≈ 1008)
    }

    @Test func `Part with custom material and semantic`() async throws {
        let visualPart = Part("reference", semantic: .visual, material: .plain(.red))

        let geometry = Box(10)
            .adding {
                Sphere(diameter: 20)
                    .inPart(visualPart)
            }

        let parts = try await geometry.parts
        let part = try #require(parts.keys.first { $0.name == "reference" })
        #expect(part.semantic == .visual)
        #expect(part.defaultMaterial == .plain(.red))
    }

    // MARK: - Reading parts tests

    @Test func `readingPart reads single part by instance`() async throws {
        let myPart = Part("box")

        let geometry = Box(10)
            .adding {
                Box(4)
                    .inPart(myPart)
            }
            .readingPart(myPart) { base, part in
                // Part should exist and be added to base
                base.adding { part }
            }

        // If the part was read correctly, the bounds should include both boxes
        let bounds = try await geometry.bounds
        #expect(bounds ≈ .init(minimum: [0, 0, 0], maximum: [10, 10, 10]))
    }

    @Test func `readingPart returns nil for missing part`() async throws {
        let myPart = Part("nonexistent")

        let geometry = Box(10)
            .readingPart(myPart) { base, part in
                // Should return base with added sphere only if part is nil
                if part == nil {
                    base.adding { Sphere(diameter: 20) }
                } else {
                    base
                }
            }

        // Sphere was added because part was nil
        let bounds = try await geometry.bounds
        #expect(bounds ≈ .init(minimum: [-10, -10, -10], maximum: [10, 10, 10]))
    }

    @Test func `readingParts reads multiple parts by instance`() async throws {
        let part1 = Part("box1")
        let part2 = Part("box2")

        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(part1)
            Box(2)
                .inPart(part2)
        }.readingParts(matching: [part1, part2]) { base, parts in
            // Stack the parts vertically if both exist
            if parts.count == 2 {
                base.adding {
                    Sphere(diameter: 1)
                        .translated(y: 100)
                }
            } else {
                base
            }
        }

        // Sphere was added because both parts were found
        let bounds = try await geometry.bounds
        #expect(bounds?.maximum.y ≈ 100.5)
    }

    @Test func `readingPart by name reads single named part`() async throws {
        let geometry = Box(10)
            .adding {
                Box(4)
                    .inPart(named: "box")
            }
            .readingPart(ofType: .solid, named: "box") { base, part in
                if part != nil {
                    base.adding { Sphere(diameter: 1).translated(y: 50) }
                } else {
                    base
                }
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.maximum.y ≈ 50.5)
    }

    @Test func `readingParts by semantic reads all parts of type`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "solid1")
            Box(2)
                .inPart(named: "solid2")
            Sphere(diameter: 5)
                .inPart(named: "visual", type: .visual)
        }.readingParts(ofType: .solid) { base, parts in
            // Add marker sphere if we found exactly 2 solid parts
            if parts.count == 2 {
                base.adding { Sphere(diameter: 1).translated(y: 100) }
            } else {
                base
            }
        }

        let bounds = try await geometry.bounds
        #expect(bounds?.maximum.y ≈ 100.5)
    }

    @Test func `reading parts does not remove them`() async throws {
        let myPart = Part("box")

        let geometry = Box(10)
            .adding {
                Box(4)
                    .inPart(myPart)
            }
            .readingPart(myPart) { base, _ in base }

        #expect(try await geometry.partNames == ["box"])
    }

    // MARK: - Subtraction tests

    @Test func `subtractingParts with Part instances`() async throws {
        let holePart = Part("hole")

        let geometry = Box(10)
            .adding {
                Cylinder(diameter: 4, height: 12)
                    .inPart(holePart)
            }
            .subtractingParts([holePart])

        let mainVolume = try await geometry.mainModelMeasurements.volume
        #expect(mainVolume < 1000.0)  // Cylinder was subtracted
        #expect(try await geometry.partNames == ["hole"])  // Part still exists
    }

    // MARK: - Highlighted and background tests

    @Test func `highlighted geometry is placed in visual part`() async throws {
        let geometry = Box(10)
            .adding {
                Sphere(diameter: 5)
                    .highlighted()
            }

        let parts = try await geometry.parts
        let highlightedPart = parts.keys.first { $0.name == "Highlighted" }
        #expect(highlightedPart != nil)
        #expect(highlightedPart?.semantic == .visual)
    }

    @Test func `background geometry is placed in context part`() async throws {
        let geometry = Box(10)
            .adding {
                Sphere(diameter: 20)
                    .inBackground()
            }

        let parts = try await geometry.parts
        let backgroundPart = parts.keys.first { $0.name == "Background" }
        #expect(backgroundPart != nil)
        #expect(backgroundPart?.semantic == .context)
    }

    // MARK: - Additional removal tests

    @Test func `removingParts by semantic removes only matching semantic`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "solid1")
            Box(2)
                .inPart(named: "visual1", type: .visual)
        }.removingParts(ofType: .solid)

        #expect(try await geometry.partNames == ["visual1"])
    }

    @Test func `removingPart by semantic and name`() async throws {
        let geometry = Stack(.x) {
            Box(10)
            Box(4)
                .inPart(named: "box", type: .solid)
            Box(2)
                .inPart(named: "box", type: .visual)
        }.removingPart(ofType: .solid, named: "box")

        let parts = try await geometry.parts
        #expect(parts.count == 1)
        #expect(parts.keys.first?.semantic == .visual)
    }
}
