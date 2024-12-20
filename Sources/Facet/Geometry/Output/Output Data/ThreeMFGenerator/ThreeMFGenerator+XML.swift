import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

internal extension ThreeMF.ColorGroup {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "m:colorgroup")
        element["id"] = String(id)
        element.addChildren(colors.map(\.xmlElement))
        return element
    }
}

internal extension ThreeMF.Item {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "item")
        element["objectid"] = String(objectID)
        element["printable"] = printable.map { $0 ? "1" : "0" }
        return element
    }
}

internal extension ThreeMF.Object {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "object")
        element["id"] = String(id)
        element["type"] = type
        element["name"] = name
        element.addChild(mesh.xmlElement)
        return element
    }
}

internal extension ThreeMF.Mesh {
    var xmlElement: XMLElement {
        let mesh = XMLElement(name: "mesh")
        mesh.addChild(vertices.verticesXMLElement)
        mesh.addChild(triangles.xmlElement)
        return mesh
    }
}

internal extension [Vector3D] {
    var verticesXMLElement: XMLElement {
        let element = XMLElement(name: "vertices")
        element.addChildren(map(\.xmlElement))
        return element
    }
}

internal extension Vector3D {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "vertex")
        element["x"] = String(format: "%g", x)
        element["y"] = String(format: "%g", y)
        element["z"] = String(format: "%g", z)
        return element
    }
}

internal extension [ThreeMF.Mesh.Triangle] {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "triangles")
        element.addChildren(map(\.xmlElement))
        return element
    }
}

internal extension ThreeMF.Mesh.Triangle {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "triangle")
        element["v1"] = String(v1)
        element["v2"] = String(v2)
        element["v3"] = String(v3)
        if let color {
            element["pid"] = String(color.group)
            element["p1"] = String(color.colorIndex)
        }
        return element
    }
}

internal extension Color {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "m:color")
        let (red, green, blue, alpha) = rgbaComponents
        element["color"] = String(
            format: "#%02X%02X%02X%02X",
            Int(round(red * 255.0)), Int(round(green * 255.0)), Int(round(blue * 255.0)), Int(round(alpha * 255.0))
        )
        return element
    }
}

internal extension ThreeMF.Metadata {
    var xmlElement: XMLElement {
        let element = XMLElement(name: "metadata")
        element["name"] = name.key
        element.stringValue = value
        return element
    }
}

internal extension XMLElement {
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

    func addChildren(_ children: [XMLNode]) {
        for child in children {
            addChild(child)
        }
    }
}
