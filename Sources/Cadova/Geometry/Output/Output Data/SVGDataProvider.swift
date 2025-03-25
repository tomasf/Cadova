import Foundation

struct SVGDataProvider: OutputDataProvider {
    let output: Output2D
    let fileExtension = "svg"

    func generateOutput() throws -> Data {
        let primitive = output.primitive.scale(Vector2D(1, -1))
        let bounds = primitive.bounds
        let shapePoints = primitive.polygons()

        let svg = XMLElement(name: "svg")
        svg["xmlns"] = "http://www.w3.org/2000/svg"
        svg["viewBox"] = String(format: "%g %g %g %g",
                                bounds.min.x, bounds.min.y,
                                bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y)

        let path = XMLElement(name: "path")
        path["fill"] = "black"
        path["d"] = shapePoints.map {
            "M " + $0.vertices.map {
                String(format: "%g,%g", $0.x, $0.y)
            }.joined(separator: " ")
        }.joined(separator: " ")

        svg.addChild(path)

        let document = XMLDocument(rootElement: svg)
        return document.xmlData(options: .nodeCompactEmptyElement)
    }
}


fileprivate extension XMLElement {
    subscript(attribute: String) -> String? {
        get {
            self.attribute(forName: attribute)?.stringValue
        }
        set {
            if let newValue {
                if let existingAttribute = self.attribute(forName: attribute) {
                    existingAttribute.stringValue = newValue
                } else {
                    addAttribute(XMLNode.attribute(withName: attribute, stringValue: newValue) as! XMLNode)
                }
            } else {
                self.removeAttribute(forName: attribute)
            }
        }
    }
}
