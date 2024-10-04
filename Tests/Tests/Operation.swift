import Testing
@testable import SwiftSCAD

struct OperationTests {
    @Test func operations() {
        Box([1,2,3])
            .readingOperation { #expect($0 == .addition) }
            .subtracting {
                Sphere(diameter: 3)
                    .readingOperation { #expect($0 == .subtraction) }
                    .subtracting {
                        Box([1,2,3])
                            .readingOperation { #expect($0 == .addition) }
                    }
                    .readingOperation { #expect($0 == .subtraction) }
            }
            .readingOperation { #expect($0 == .addition) }
            .triggerEvaluation()
    }
}
