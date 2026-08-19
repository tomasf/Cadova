import Foundation

/// A model push sent from Cadova to a locally-listening consumer (e.g. Cadova Viewer),
/// carrying the same mesh/material data that's about to be written to a 3MF file, without
/// the zip/XML overhead of that file. See ``LiveLinkClient`` and ``LiveLinkServer``.
public struct LiveLinkMessage: Sendable, Codable {
    /// The value the sender puts in the 3MF Production Extension's `<build p:UUID="...">`
    /// attribute of the file it writes to `path`, so a receiver can recognize "this on-disk
    /// file is the one I already applied via LiveLink" without re-reading the file's content.
    /// It carries no meaning beyond that and is never compared across separate sender processes.
    public let buildUUID: UUID

    /// The absolute path of the file this message's content corresponds to.
    public let path: String

    /// One entry per part/object in the model.
    public let parts: [Part]

    public init(buildUUID: UUID, path: String, parts: [Part]) {
        self.buildUUID = buildUUID
        self.path = path
        self.parts = parts
    }

    public struct Part: Sendable {
        public let name: String

        /// The raw value of Cadova's `PartSemantic` ("solid", "context", or "visual") — the same
        /// string written into a 3MF file's custom `cadova:semantic` item attribute, so a receiver
        /// parsing this sees exactly what it would see reading the file back. An unrecognized
        /// value should be treated the same way the 3MF reading path treats a missing attribute:
        /// default to "solid".
        public let semantic: String

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
            semantic: String,
            vertices: [Double],
            triangles: [UInt32],
            triangleMaterialIndices: [Int32],
            defaultMaterialIndex: Int32?,
            materials: [MaterialEntry]
        ) {
            self.name = name
            self.semantic = semantic
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
