import Testing
@testable import Cadova

struct ResultTests {
    @Test func resultElementCombination() async {
        await Box(1)
            .withTestValue(1)
            .adding {
                Sphere(diameter: 10)
                    .withTestValue(7)
            }
            .expectTestValue(8)
            .subtracting {
                Cylinder(diameter: 10, height: 4)
                    .withTestValue(2)
            }
            .expectTestValue(10)
            .triggerEvaluation()
    }

    @Test func resultElementReplacement() async {
        await Box(1)
            .withTestValue(1)
            .adding { Box(2) }
            .withTestValue(3)
            .expectTestValue(3)
            .triggerEvaluation()
    }
}

fileprivate struct TestElement: ResultElement {
    let value: Int

    init(combining elements: [TestElement]) {
        self.init(value: elements.map(\.value).reduce(0, +))
    }
    
    init(value: Int) {
        self.value = value
    }

    init() {
        self.init(value: 0)
    }
}

fileprivate extension Geometry {
    func withTestValue(_ value: Int) -> D.Geometry {
        withResult(TestElement(value: value))
    }

    func expectTestValue(_ value: Int) -> D.Geometry {
        readingResult(TestElement.self) { geometry, testElement in
            #expect(testElement.value == value)
            return geometry
        }
    }
}
