import Foundation
import Nodal

struct SVGDataProvider: OutputDataProvider {
    let result: D2.BuildResult
    let options: ModelOptions
    let fileExtension = "svg"

    func generateOutput(context: EvaluationContext) async throws -> Data {
        let expression = GeometryNode2D.transform(result.node, transform: .scaling(x: 1, y: -1))
        let nodeResult = await context.result(for: expression)

        let bounds = nodeResult.concrete.bounds
        let shapePoints = nodeResult.concrete.polygons()

        let document = Document()
        let svg = document.makeDocumentElement(name: "svg", defaultNamespace: "http://www.w3.org/2000/svg")
        svg[attribute: "viewBox"] = String(format: "%g %g %g %g",
                                           bounds.min.x, bounds.min.y,
                                           bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y)

        let path = svg.addElement("path")
        path[attribute: "fill"] = "black"
        path[attribute: "d"] = shapePoints.map {
            "M " + $0.vertices.map {
                String(format: "%g,%g", $0.x, $0.y)
            }.joined(separator: " ")
        }.joined(separator: " ")

        return try document.xmlData()
    }
}
