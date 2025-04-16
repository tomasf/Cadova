import Testing
@testable import Cadova

struct ExtrudePolygonTest {
    @Test func testHelix(){
        Polygon([[0, 3], [-1, 0], [1, 0]])
            .transformed(.translation(x: 8))
            .extrudedAlongHelix(pitch: 10, height: 20)
            .expectCodeEquals(file: "helix")
    }
}
