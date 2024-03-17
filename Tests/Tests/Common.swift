import XCTest
@testable import SwiftSCAD

fileprivate func assertEqualGeometry(_ geometry: any Geometry2D, toFile fileName: String) {
    assertEqualOutputs(geometry.output(in: .defaultEnvironment), toFile: fileName)
}

fileprivate func assertEqualGeometry(_ geometry: any Geometry3D, toFile fileName: String) {
    assertEqualOutputs(geometry.output(in: .defaultEnvironment), toFile: fileName)
}

fileprivate func assertEqualOutputs<V>(_ output: GeometryOutput<V>, toFile fileName: String) {
    let url = Bundle.module.url(forResource: fileName, withExtension: "scad", subdirectory: "SCAD")!
    let correctString = try! String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let generatedString = output.scadCode.trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertEqual(generatedString, correctString)
}

extension Geometry3D {
    func assertEqual(toFile fileName: String) {
        assertEqualGeometry(self.usingDefaultFacets(), toFile: fileName)
    }
}

extension Geometry2D {
    func assertEqual(toFile fileName: String) {
        assertEqualGeometry(self.usingDefaultFacets(), toFile: fileName)
    }
}
