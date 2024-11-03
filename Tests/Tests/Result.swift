import Testing
@testable import SwiftSCAD

struct ResultTests {
    @Test func resultElementCombination() {
        let geometry = Box(1)
            .withTestValue(1)
            .adding {
                Sphere(diameter: 10)
                    .withTestValue(7)
            }
            .subtracting {
                Cylinder(diameter: 10, height: 4)
                    .withTestValue(2)
            }

        #expect(geometry.testValue == 6)
    }

    @Test func resultElementReplacement() {
        let geometry = Box(1)
            .withTestValue(1)
            .adding { Box(2) }
            .withTestValue(3)

        #expect(geometry.testValue == 3)
    }
}

fileprivate struct TestElement: ResultElement {
    let value: Int

    static func combine(elements: [TestElement], for operation: GeometryCombination) -> TestElement? {
        if operation == .difference {
            TestElement(value: elements[0].value - elements[1].value)
        } else {
            TestElement(value: elements.map(\.value).reduce(0, +))
        }
    }
}

fileprivate extension Geometry3D {
    func withTestValue(_ value: Int) -> any Geometry3D {
        withResult(TestElement(value: value))
    }

    var testValue: Int? {
        evaluated(in: .defaultEnvironment).elements[TestElement.self]?.value
    }
}
