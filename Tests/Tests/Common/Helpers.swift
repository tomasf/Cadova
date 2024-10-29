import Testing
import Foundation
@testable import SwiftSCAD

func scadFile(_ fileName: String) -> String {
    let url = Bundle.module.url(forResource: fileName, withExtension: "scad", subdirectory: "SCAD")!
    return try! String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
}

extension Geometry2D {
    var code: String {
        usingDefaultFacets().codeFragment(in: .defaultEnvironment).scadCode
    }

    func triggerEvaluation() {
        _ = codeFragment(in: .defaultEnvironment)
    }

    var bounds: BoundingBox2D? {
        boundary(in: .defaultEnvironment).boundingBox
    }
}

extension Geometry3D {
    func readingOperation(_ action: @escaping (Environment.Operation) -> ()) -> any Geometry3D {
        readEnvironment { environment in
            action(environment.operation)
            return self
        }
    }

    var code: String {
        let code1 = usingDefaultFacets().codeFragment(in: .defaultEnvironment).scadCode
        let code2 = usingDefaultFacets().codeFragment(in: .defaultEnvironment).scadCode
        #expect(code1 == code2, "Inconsistent code generation")
        return code1
    }

    var bounds: BoundingBox3D? {
        boundary(in: .defaultEnvironment).boundingBox
    }

    func triggerEvaluation() {
        _ = codeFragment(in: .defaultEnvironment)
    }
}
