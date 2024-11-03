import Testing
import SwiftSCAD

struct EnvironmentTest {
    @Test func injection(){
        let shape = TestShape()
        // Injected environment values are only valid inside body
        #expect(shape.injectedTestValue == 0)

        shape
            .withTestEnvironmentValue(381)
            .triggerEvaluation()

        // Was it properly reset after evaluation?
        #expect(shape.injectedTestValue == 0)
    }
}

fileprivate struct TestShape: Shape3D {
    @EnvironmentValue(\.testEnvironmentValue) var injectedTestValue

    var body: any Geometry3D {
        // Basic case
        #expect(injectedTestValue == 381)

        readEnvironment(\.testEnvironmentValue) {
            // Explicit read. The value should be unchanged.
            #expect($0 == 381)

            // This happens outside of the actual call of body, but still inside
            // evaluated(in:), and we still want the wrapper value to be valid here
            #expect(injectedTestValue == 381)
        }

        Box(10)
            .adding {
                // This is actually still inside of the call of body
                // because the builder is evaluated in adding()
                #expect(injectedTestValue == 381)

                readEnvironment(\.testEnvironmentValue) { innerTestValue in
                    #expect(innerTestValue == 38)
                }
            }
            .withTestEnvironmentValue(38)
    }
}

fileprivate extension Environment {
    private static let key = ValueKey("SwiftSCAD.TestValue")

    var testEnvironmentValue: Int {
        self[Self.key] as? Int ?? 0
    }

    func withTestEnvironmentValue(_ value: Int) -> Environment {
        setting(key: Self.key, value: value)
    }
}

fileprivate extension Geometry3D {
    func withTestEnvironmentValue(_ value: Int) -> Geometry3D {
        withEnvironment { $0.withTestEnvironmentValue(value) }
    }
}
