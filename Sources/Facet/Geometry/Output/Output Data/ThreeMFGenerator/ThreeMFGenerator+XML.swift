import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

internal extension ThreeMF.ColorGroup {
    var xmlElement: XMLElement {
        XMLElement("m:colorgroup", [
            "id": String(id)
        ], children: colors.map(\.xmlElement))
    }
}

internal extension ThreeMF.Item {
    var xmlElement: XMLElement {
        XMLElement("item", [
            "objectid": String(objectID),
            "printable": printable.map { $0 ? "1" : "0" }
        ])
    }
}

internal extension ThreeMF.Object {
    var xmlElement: XMLElement {
        XMLElement("object", [
            "id": String(id),
            "type": type,
            "name": name
        ], children: [mesh.xmlElement])
    }
}

internal extension ThreeMF.Mesh {
    var xmlElement: XMLElement {
        XMLElement("mesh", children: [vertices.verticesXMLElement, triangles.xmlElement])
    }
}

internal extension [Vector3D] {
    var verticesXMLElement: XMLElement {
        XMLElement("vertices", children: map(\.xmlElement))
    }
}

internal extension Vector3D {
    var xmlElement: XMLElement {
        XMLElement("vertex", [
            "x": String(format: "%g", x),
            "y": String(format: "%g", y),
            "z": String(format: "%g", z)
        ])
    }
}

internal extension [ThreeMF.Mesh.Triangle] {
    var xmlElement: XMLElement {
        XMLElement("triangles", children: map(\.xmlElement))
    }
}

internal extension ThreeMF.Mesh.Triangle {
    var xmlElement: XMLElement {
        XMLElement("triangle", [
            "v1": String(v1),
            "v2": String(v2),
            "v3": String(v3),
            "pid": color.map { String($0.group) },
            "p1": color.map { String($0.colorIndex) }
        ])
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
    convenience init(_ name: String, _ attributes: [String: String?] = [:], children childElements: [XMLElement] = []) {
        self.init(name: name)
        setChildren(childElements)
        setAttributesWith(attributes.compactMapValues { $0 })
    }

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
