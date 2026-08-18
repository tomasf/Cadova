import Foundation

/// A model push sent from Cadova to a locally-listening consumer (e.g. Cadova Viewer),
/// carrying the same mesh/material data that's about to be written to a 3MF file, without
/// the zip/XML overhead of that file. See ``LiveLinkClient`` and ``LiveLinkServer``.
public struct LiveLinkMessage: Sendable, Codable {
    /// Opaque per-save identifier. The sender embeds the same value in the 3MF file it writes
    /// to `path`, so a receiver can recognize "this on-disk file is the one I already applied
    /// via LiveLink" without re-reading the file's content. It carries no meaning beyond that
    /// and is never compared across separate sender processes.
    public let token: UUID

    /// The absolute path of the file this message's content corresponds to.
    public let path: String

    /// One entry per part/object in the model.
    public let parts: [Part]

    public init(token: UUID, path: String, parts: [Part]) {
        self.token = token
        self.path = path
        self.parts = parts
    }

    public struct Part: Sendable {
        public let name: String
        public let isPrintable: Bool

        /// A 4x4 affine transform in row-major order (16 values), or `nil` for identity.
        public let transform: [Double]?

        /// Flat vertex positions, 3 `Double`s (x, y, z) per vertex.
        public let vertices: [Double]

        /// Flat triangle vertex indices, 3 per triangle, indexing into `vertices`.
        public let triangles: [UInt32]

        /// One entry per triangle (parallel to `triangles`), indexing into `materials`.
        /// `-1` means "use `defaultMaterialIndex`".
        public let triangleMaterialIndices: [Int32]

        /// Index into `materials` used for triangles that don't specify their own, and for
        /// the part as a whole when it has no per-triangle materials. `nil` means no material.
        public let defaultMaterialIndex: Int32?

        /// The deduplicated palette of materials referenced by this part's triangles.
        public let materials: [MaterialEntry]

        public init(
            name: String,
            isPrintable: Bool,
            transform: [Double]?,
            vertices: [Double],
            triangles: [UInt32],
            triangleMaterialIndices: [Int32],
            defaultMaterialIndex: Int32?,
            materials: [MaterialEntry]
        ) {
            self.name = name
            self.isPrintable = isPrintable
            self.transform = transform
            self.vertices = vertices
            self.triangles = triangles
            self.triangleMaterialIndices = triangleMaterialIndices
            self.defaultMaterialIndex = defaultMaterialIndex
            self.materials = materials
        }
    }

    public struct MaterialEntry: Sendable, Codable, Hashable {
        public let color: RGBA
        public let name: String?
        public let metallicness: Double?
        public let roughness: Double?

        public init(color: RGBA, name: String? = nil, metallicness: Double? = nil, roughness: Double? = nil) {
            self.color = color
            self.name = name
            self.metallicness = metallicness
            self.roughness = roughness
        }
    }

    public struct RGBA: Sendable, Codable, Hashable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8

        public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }
}

public extension LiveLinkMessage {
    /// The 3MF `<metadata name="...">` name a sender embeds its `token` under when it writes the
    /// file a push corresponds to, so a receiver that already applied that push can recognize the
    /// file's on-disk write once it lands and skip a redundant reload. The single source of truth
    /// for this string, since a sender (writing it into 3MF metadata) and a receiver (reading it
    /// back out) both need to agree on it independently.
    static let tokenMetadataName = "cadova:livelinktoken"
}
