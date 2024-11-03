import Testing
import Foundation
@testable import SwiftSCAD

func scadFile(_ fileName: String) -> String {
    let url = Bundle.module.url(forResource: fileName, withExtension: "scad", subdirectory: "SCAD")!
    return try! String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
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
}

extension Geometry3D {
    func readingOperation(_ action: @escaping (Environment.Operation) -> ()) -> any Geometry3D {
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

    var bounds: BoundingBox3D? {
        evaluated(in: .defaultEnvironment).boundary.boundingBox
    }

    func triggerEvaluation() {
        _ = evaluated(in: .defaultEnvironment)
    }
}
