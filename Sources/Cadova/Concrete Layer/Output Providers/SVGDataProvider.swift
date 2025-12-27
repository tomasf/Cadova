import Foundation
internal import Nodal

struct SVGDataProvider: OutputDataProvider {
    let result: D2.BuildResult
    let options: ModelOptions
    let fileExtension = "svg"

    func generateOutput(context: EvaluationContext) async throws -> Data {
        let node = GeometryNode.transform(result.node, transform: .scaling(x: 1, y: -1))
        let nodeResult = try await context.result(for: node)

        let bounds = BoundingBox2D(nodeResult.concrete.bounds)
        let shapePoints = nodeResult.concrete.polygons()

        let document = Document()
        let svg = document.makeDocumentElement(name: "svg", defaultNamespace: "http://www.w3.org/2000/svg")
        svg[attribute: "viewBox"] = String(format: "%g %g %g %g",
                                           bounds.minimum.x, bounds.minimum.y,
                                           bounds.size.x, bounds.size.y)

        let metadata = options[Metadata.self]
        if let title = metadata.title {
            svg.addElement("title").textContent = title
        }
        if let desc = metadata.description {
            svg.addElement("desc").textContent = desc
        }

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
