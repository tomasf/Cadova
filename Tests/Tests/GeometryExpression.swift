import Testing
@testable import Cadova

struct GeometryExpressionTests {
    @Test func testRawEquality() throws {
        let raw1 = GeometryExpression2D.raw(.empty, key: .init("test"))
        let raw2 = GeometryExpression2D.raw(.circle(radius: 10, segmentCount: 20), key: .init("test"))
        let raw3 = GeometryExpression2D.raw(.circle(radius: 10, segmentCount: 20), key: .init("test2"))
        let raw4 = GeometryExpression2D.raw(.square(size: Vector2D(1, 2)), key: .init("test2"))

        #expect(raw1 == raw2)
        #expect(raw2 != raw3)
        #expect(raw3 == raw4)

        #expect([raw1: "foo"][raw2] == "foo")
    }
}
