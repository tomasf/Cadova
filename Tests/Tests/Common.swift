import XCTest
@testable import SwiftSCAD

fileprivate func assertEqualGeometry(_ geometry: any Geometry2D, toFile fileName: String) {
    assertEqualOutputs(geometry.invocation(in: .defaultEnvironment), toFile: fileName)
}

fileprivate func assertEqualGeometry(_ geometry: any Geometry3D, toFile fileName: String) {
    assertEqualOutputs(geometry.invocation(in: .defaultEnvironment), toFile: fileName)
}

fileprivate func assertEqualOutputs(_ invocation: Invocation, toFile fileName: String) {
    let url = Bundle.module.url(forResource: fileName, withExtension: "scad", subdirectory: "SCAD")!
    let correctString = try! String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let generatedString = invocation.scadCode.trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertEqual(generatedString, correctString)
}

extension Geometry2D {
    func assertEqual(toFile fileName: String) {
        assertEqualGeometry(self.usingDefaultFacets(), toFile: fileName)
    }

    @discardableResult
    func assertBoundsEqual(_ correctBB: BoundingBox2D) -> any Geometry2D {
        let generatedBB = boundary(in: .defaultEnvironment).boundingBox
        generatedBB!.assertEqual(to: correctBB)
        return self
    }

    @discardableResult
    func assertBoundsEqual(min: Vector2D, max: Vector2D) -> any Geometry2D {
        assertBoundsEqual(.init(minimum: min, maximum: max))
        return self
    }

    @discardableResult
    func assertBoundsEqual(@UnionBuilder2D _ other: () -> any Geometry2D) -> any Geometry2D {
        let bb1 = self.boundary(in: .defaultEnvironment).boundingBox
        let bb2 = other().boundary(in: .defaultEnvironment).boundingBox
        bb1!.assertEqual(to: bb2!)
        return self
    }
}

extension Geometry3D {
    func assertEqual(toFile fileName: String) {
        assertEqualGeometry(self.usingDefaultFacets(), toFile: fileName)
    }

    @discardableResult
    func assertBoundsEqual(_ correctBB: BoundingBox3D) -> any Geometry3D {
        let generatedBB = boundary(in: .defaultEnvironment).boundingBox
        generatedBB?.assertEqual(to: correctBB)
        return self
    }

    @discardableResult
    func assertBoundsEqual(min: Vector3D, max: Vector3D) -> any Geometry3D {
        assertBoundsEqual(.init(minimum: min, maximum: max))
        return self
    }

    @discardableResult
    func assertBoundsEqual(@UnionBuilder3D _ other: () -> any Geometry3D) -> any Geometry3D {
        let bb1 = self.boundary(in: .defaultEnvironment).boundingBox
        let bb2 = other().boundary(in: .defaultEnvironment).boundingBox
        bb1!.assertEqual(to: bb2!)
        return self
    }
}

extension Vector {
    var stringRepresentation: String {
        "[" + elements.map { String(format: "%.03f", $0) }.joined(separator: ", ") + "]"
    }
}

extension BoundingBox {
    var stringRepresentation: String {
        "min: \(minimum.stringRepresentation), max: \(maximum.stringRepresentation)"
    }

    func assertEqual(to other: BoundingBox) {
        XCTAssertEqual(stringRepresentation, other.stringRepresentation)
    }
}
