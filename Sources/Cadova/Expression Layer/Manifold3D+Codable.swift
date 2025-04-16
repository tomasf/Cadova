import Foundation
import Manifold3D

extension MeshGL: Codable {
    enum CodingKeys: String, CodingKey {
        case triangles
        case vertices
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            vertices: try container.decode([Vector3D].self, forKey: .vertices),
            triangles: try container.decode([Triangle].self, forKey: .triangles)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vertices.map { Vector3D($0) }, forKey: .vertices)
        try container.encode(triangles, forKey: .triangles)
    }
}

extension Triangle: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let indices = try container.decode([VertexIndex].self)
        self.init(indices[0], indices[1], indices[2])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode([a, b, c])
    }
}

extension Manifold3D.Polygon: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(vertices.map { Vector2D($0) })
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(vertices: try container.decode([Vector2D].self))
    }
}
