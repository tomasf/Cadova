import Foundation

/// `Part`'s bulk numeric fields (vertices/triangles/material indices) can run into the millions
/// of elements for a real mesh. `PropertyListEncoder`/`Decoder`'s synthesized `Codable` conformance
/// walks arrays like that one element at a time through `KeyedEncodingContainer`, which is slow
/// enough to be a real bottleneck (multi-second, not the sub-second push this is supposed to be).
/// Encoding those fields as raw `Data` instead — a single bulk memory copy either direction — is
/// what keeps this fast; `Data` already has an efficient built-in `Codable` conformance.
extension LiveLinkMessage.Part: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, isPrintable, vertices, triangles, triangleMaterialIndices, defaultMaterialIndex, materials
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isPrintable = try container.decode(Bool.self, forKey: .isPrintable)
        vertices = try container.decode(Data.self, forKey: .vertices).asArray()
        triangles = try container.decode(Data.self, forKey: .triangles).asArray()
        triangleMaterialIndices = try container.decode(Data.self, forKey: .triangleMaterialIndices).asArray()
        defaultMaterialIndex = try container.decodeIfPresent(Int32.self, forKey: .defaultMaterialIndex)
        materials = try container.decode([LiveLinkMessage.MaterialEntry].self, forKey: .materials)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(isPrintable, forKey: .isPrintable)
        try container.encode(vertices.asData(), forKey: .vertices)
        try container.encode(triangles.asData(), forKey: .triangles)
        try container.encode(triangleMaterialIndices.asData(), forKey: .triangleMaterialIndices)
        try container.encodeIfPresent(defaultMaterialIndex, forKey: .defaultMaterialIndex)
        try container.encode(materials, forKey: .materials)
    }
}

private extension Array where Element: FixedWidthInteger {
    func asData() -> Data {
        withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

private extension Array where Element == Double {
    func asData() -> Data {
        withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

private extension Data {
    /// Bulk-copies these bytes into a freshly-allocated, correctly-aligned `[Element]`, rather than
    /// binding this `Data`'s own (not necessarily aligned) storage in place.
    func asArray<Element>() -> [Element] {
        let count = self.count / MemoryLayout<Element>.stride
        return withUnsafeBytes { raw in
            [Element](unsafeUninitializedCapacity: count) { buffer, initializedCount in
                raw.copyBytes(to: UnsafeMutableRawBufferPointer(buffer))
                initializedCount = count
            }
        }
    }
}
