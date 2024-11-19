import Testing
import Foundation
@testable import SwiftSCAD

fileprivate extension URL {
    static func testSCADFile(named fileName: String) -> URL {
        Bundle.module.url(forResource: fileName, withExtension: "scad", subdirectory: "SCAD")!
    }

    static func testSCADFileInSource(named fileName: String) -> URL {
        URL.homeDirectory.appendingPathComponent("Documents/Projects/SwiftSCAD/Tests/Tests/SCAD/\(fileName).scad")
    }
}

extension Geometry2D {
    var code: String {
        usingDefaultFacets().evaluated(in: .defaultEnvironment).codeFragment.scadCode
    }

    func triggerEvaluation() {
        _ = evaluated(in: .defaultEnvironment)
    }

    var bounds: BoundingBox2D? {
        evaluated(in: .defaultEnvironment).boundary.boundingBox
    }

    func expectCodeEquals(file fileName: String) {
        let correctCode = try! String(contentsOf: .testSCADFile(named: fileName), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(code == correctCode)
    }

    func setAsExpected(name: String) {
        try! code.write(to: .testSCADFileInSource(named: name), atomically: true, encoding: .utf8)
    }
}

extension Geometry3D {
    func readingOperation(_ action: @escaping (EnvironmentValues.Operation) -> ()) -> any Geometry3D {
        readEnvironment { environment in
            action(environment.operation)
            return self
        }
    }

    var code: String {
        let code1 = usingDefaultFacets().evaluated(in: .defaultEnvironment).codeFragment.scadCode
        let code2 = usingDefaultFacets().evaluated(in: .defaultEnvironment).codeFragment.scadCode
        #expect(code1 == code2, "Inconsistent code generation")
        return code1
    }
    
    func expectCodeEquals(file fileName: String) {
        let correctCode = try! String(contentsOf: .testSCADFile(named: fileName), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(code == correctCode)
    }

    var bounds: BoundingBox3D? {
        evaluated(in: .defaultEnvironment).boundary.boundingBox
    }

    func triggerEvaluation() {
        _ = evaluated(in: .defaultEnvironment)
    }

    func setAsExpected(name: String) {
        try! code.write(to: .testSCADFileInSource(named: name), atomically: true, encoding: .utf8)
    }
}
