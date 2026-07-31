import Foundation

/// Wraps a mask geometry supplied to `within(mask:)`.
///
/// The geometry itself is excluded from `Hashable`/`Codable`/`Equatable` (see the conformances
/// below) — it can't be compared or serialized in general. Caching still works correctly because
/// `shapingEdges(_:matching:)`, the only cache-key consumer of `EdgeQuery`, separately evaluates
/// each mask into a `GeometryNode` and folds that node into the cache key itself. `EdgeQuery`'s own
/// conformances only need to distinguish "how many masks, in what combination with everything
/// else" — not the mask contents.
internal struct MaskConstraint: Sendable {
    let geometry: any Geometry3D
}

extension MaskConstraint: Hashable {
    static func == (lhs: MaskConstraint, rhs: MaskConstraint) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}

extension MaskConstraint: Codable {
    // Not meaningfully decodable; a decoded query's masks carry no usable geometry. Identity for
    // caching purposes comes from the separately-folded-in mask node, not from round-tripping this.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        _ = try container.decode(Bool.self)
        self.geometry = Empty<D3>()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(true)
    }
}
