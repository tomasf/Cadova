import XCTest
@testable import SwiftSCAD

final class ResultTests: XCTestCase {
    func testResultElementCombination() {
        let testValue = Box(1)
            .withTestValue(1)
            .adding {
                Sphere(diameter: 10)
                    .withTestValue(7)
            }
            .subtracting {
                Cylinder(diameter: 10, height: 4)
                    .withTestValue(2)
            }
            .evaluateTestValue()

        XCTAssertEqual(testValue, 6)
    }

    func testResultElementReplacement() {
        let testValue = Box(1)
            .withTestValue(1)
            .adding { Box(2) }
            .withTestValue(3)
            .evaluateTestValue()

        XCTAssertEqual(testValue, 3)
    }
}

struct TestElement: ResultElement {
    let value: Int

    static func combine(elements: [TestElement], for operation: GeometryCombination) -> TestElement? {
        if operation == .difference {
            TestElement(value: elements[0].value - elements[1].value)
        } else {
            TestElement(value: elements.map(\.value).reduce(0, +))
        }
    }
}

extension Geometry3D {
    func withTestValue(_ value: Int) -> any Geometry3D {
        withResult(TestElement(value: value))
    }

    func evaluateTestValue() -> Int? {
        elements(in: .defaultEnvironment)[TestElement.self]?.value
    }
}
