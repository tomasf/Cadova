import Foundation
import Manifold3D
internal import ThreeMF

extension Color {
    var threeMFColor: ThreeMF.Color {
        ThreeMF.Color(
            red: UInt8(round(red * 255.0)),
            green: UInt8(round(green * 255.0)),
            blue: UInt8(round(blue * 255.0)),
            alpha: UInt8(round(alpha * 255.0))
        )
    }
}

extension Manifold3D.Vector3 {
    var threeMFVector: ThreeMF.Mesh.Vertex {
        .init(x: Double(x), y: Double(y), z: Double(z))
    }
}

extension PropertyReference {
    static func addColor(_ color: Color, to colorGroup: inout ColorGroup) -> PropertyReference {
        let threeMFColor = color.threeMFColor
        if let index = colorGroup.colors.firstIndex(of: threeMFColor) {
            return PropertyReference(groupID: colorGroup.id, index: index)
        } else {
            let index = colorGroup.addColor(threeMFColor)
            return PropertyReference(groupID: colorGroup.id, index: index)
        }
    }

    static func addMetallic(
        baseColor: Color, name: String?, metallicness: Double, roughness: Double,
        to properties: inout MetallicDisplayProperties, colorGroup: inout ColorGroup
    ) -> PropertyReference {
        let name = name ?? "Metallic \(properties.metallics.count + 1)"
        let metallic = Metallic(name: name, metallicness: metallicness, roughness: roughness)
        let threeMFColor = baseColor.threeMFColor

        let index = properties.metallics.indices.first { index in
            properties.metallics[index] == metallic && colorGroup.colors[index] == threeMFColor
        } ?? {
            properties.addMetallic(metallic)
            return colorGroup.addColor(threeMFColor)
        }()

        return PropertyReference(groupID: colorGroup.id, index: index)
    }

    static func addMaterial(
        _ material: Material,
        mainColorGroup: inout ColorGroup,
        metallicColorGroup: inout ColorGroup,
        metallicProperties: inout MetallicDisplayProperties
    ) -> PropertyReference {
        if let properties = material.physicalProperties {
            addMetallic(
                baseColor: material.baseColor,
                name: material.name,
                metallicness: properties.metallicness,
                roughness: properties.roughness,
                to: &metallicProperties,
                colorGroup: &metallicColorGroup
            )
        } else {
            addColor(material.baseColor, to: &mainColorGroup)
        }
    }
}
