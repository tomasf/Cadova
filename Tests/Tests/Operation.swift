import Testing
@testable import Cadova

struct OperationTests {
    @Test func operations() async throws {
        try await Box(1)
            .readingOperation { #expect($0 == .addition) }
            .subtracting {
                Sphere(diameter: 3)
                    .readingOperation { #expect($0 == .subtraction) }
                    .subtracting {
                        Box(2)
                            .readingOperation { #expect($0 == .addition) }
                    }
                    .readingOperation { #expect($0 == .subtraction) }
            }
            .readingOperation { #expect($0 == .addition) }
            .triggerEvaluation()
    }
}
