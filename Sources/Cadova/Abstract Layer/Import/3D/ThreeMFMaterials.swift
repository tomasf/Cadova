import Foundation
internal import ThreeMF

/// Turning the property references of a loaded 3MF package into materials.
///
/// Color groups, base material groups and composite materials become materials directly, taking
/// metallic display properties along when the group points at some. Multiproperties layer their
/// groups: the first layer's material takes each later layer's color, blended over it by the
/// layer's blend method. Property groups with no counterpart here, such as textures, resolve to no
/// material, as do references to groups or entries the model doesn't have.
///
/// A package's models each number their resources from scratch, so a reference means nothing
/// without the model file it was written in. Every lookup names that file by its index in
/// ``ModelLoader/LoadedModel/models``.
internal extension ModelLoader.LoadedModel {
    func material(for reference: PropertyReference, inModel modelIndex: Int) -> Material? {
        guard let multiproperties = resource(reference.groupID, in: modelIndex) as? Multiproperties else {
            return plainMaterial(for: reference, in: modelIndex)
        }
        guard let layers = multiproperties.layerSequences[safe: reference.index] else { return nil }

        return layers.reduce(nil) { (result: Material?, layer) in
            guard let layerMaterial = plainMaterial(for: layer.property, in: modelIndex) else { return result }
            guard let result else { return layerMaterial }
            return Material(
                name: result.name,
                baseColor: result.baseColor.layered(with: layerMaterial.baseColor, by: layer.blendMethod),
                properties: result.physicalProperties
            )
        }
    }

    /// A material from a color group, a base material group or a composite material group.
    /// Multiproperties aren't allowed to nest, so their layers only ever come here.
    private func plainMaterial(for reference: PropertyReference, in modelIndex: Int) -> Material? {
        switch resource(reference.groupID, in: modelIndex) {
        case let group as ColorGroup:
            guard let color = group.colors[safe: reference.index] else { return nil }
            let metallic = metallic(displayPropertiesID: group.displayPropertiesID, index: reference.index, in: modelIndex)
            return Material(name: metallic?.name, baseColor: Color(color), properties: metallic?.physicalProperties)

        case let group as BaseMaterialGroup:
            guard let base = group.properties[safe: reference.index] else { return nil }
            let metallic = metallic(displayPropertiesID: group.displayPropertiesID, index: reference.index, in: modelIndex)
            return Material(name: base.name, baseColor: Color(base.displayColor), properties: metallic?.physicalProperties)

        case let group as CompositeMaterialGroup:
            guard let color = compositeColor(group, index: reference.index, in: modelIndex) else { return nil }
            let metallic = metallic(displayPropertiesID: group.displayPropertiesID, index: reference.index, in: modelIndex)
            return Material(name: metallic?.name, baseColor: color, properties: metallic?.physicalProperties)

        default:
            return nil
        }
    }

    /// The display colors of a composite's base materials, mixed in the composite's proportions,
    /// as the materials extension has a viewer show it. A composite whose proportions add up to
    /// nothing, or that names a base material the group doesn't have, can't be shown.
    private func compositeColor(_ group: CompositeMaterialGroup, index: ResourceIndex, in modelIndex: Int) -> Color? {
        guard let proportions = group.composites[safe: index],
              proportions.count == group.baseMaterialIndices.count,
              let baseGroup = resource(group.baseMaterialGroupID, in: modelIndex) as? BaseMaterialGroup
        else { return nil }

        let total = proportions.reduce(0, +)
        guard total > 0 else { return nil }

        var mixed = Color(red: 0, green: 0, blue: 0, alpha: 0)
        for (baseIndex, proportion) in zip(group.baseMaterialIndices, proportions) {
            guard let base = baseGroup.properties[safe: baseIndex] else { return nil }
            mixed = mixed.adding(Color(base.displayColor), weight: proportion / total)
        }
        return mixed
    }

    /// The metallic appearance at the same index as a group's entry, when the group has display
    /// properties of that kind. The format aligns the two lists index by index.
    private func metallic(displayPropertiesID: ResourceID?, index: ResourceIndex, in modelIndex: Int) -> Metallic? {
        guard let displayPropertiesID,
              let properties = resource(displayPropertiesID, in: modelIndex) as? MetallicDisplayProperties
        else { return nil }
        return properties.metallics[safe: index]
    }

    /// A model file's resource by id. Files declare few resources, however many entries those hold,
    /// so this scans rather than indexing them.
    private func resource(_ id: ResourceID, in modelIndex: Int) -> (any Resource)? {
        models[safe: modelIndex]?.resources.resource(for: id)
    }
}

private extension Metallic {
    var physicalProperties: Material.PhysicalProperties {
        .init(metallicness: metallicness, roughness: roughness)
    }
}

private extension Color {
    /// This color with a multiproperties layer blended over it, by the formulas the materials
    /// extension gives for each blend method.
    func layered(with layer: Color, by method: Multiproperties.BlendMethod) -> Color {
        switch method {
        case .mix:
            // The layer over this color, by its own alpha.
            Color(
                red: layer.red * layer.alpha + red * (1 - layer.alpha),
                green: layer.green * layer.alpha + green * (1 - layer.alpha),
                blue: layer.blue * layer.alpha + blue * (1 - layer.alpha),
                alpha: layer.alpha + alpha * (1 - layer.alpha)
            )
        case .multiply:
            Color(red: red * layer.red, green: green * layer.green, blue: blue * layer.blue, alpha: alpha * layer.alpha)
        }
    }

    /// This color with a share of another added to every component. Mixing shares that add up
    /// to one keeps each component in range; rounding is clamped away.
    func adding(_ other: Color, weight: Double) -> Color {
        Color(
            red: (red + other.red * weight).unitClamped,
            green: (green + other.green * weight).unitClamped,
            blue: (blue + other.blue * weight).unitClamped,
            alpha: (alpha + other.alpha * weight).unitClamped
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
