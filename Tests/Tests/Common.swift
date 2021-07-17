import XCTest
@testable import SwiftSCAD

fileprivate func assertEqualGeometry(_ geometry: Geometry, toFile fileName: String) {
    let url = Bundle.module.url(forResource: fileName, withExtension: "scad", subdirectory: "SCAD")!
    let correctString = try! String(contentsOf: url, encoding: .utf8)
    let generatedString = geometry.scadString(in: Environment())
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
