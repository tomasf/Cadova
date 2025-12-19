import Foundation

/// Loads STL files (both binary and ASCII formats) into geometry.
internal struct STLLoader {
    let url: URL

    /// Loads an STL file and returns a geometry node.
    ///
    /// - Returns: The loaded geometry node.
    /// - Throws: `STLLoader.Error` if the file cannot be parsed.
    ///
    func load() throws -> D3.Node {
        let data = try Data(contentsOf: url)
        return try load(from: data)
    }

    /// Loads STL data and returns a geometry node.
    ///
    /// - Parameter data: The STL file contents.
    /// - Returns: The loaded geometry node.
    /// - Throws: `STLLoader.Error` if the data cannot be parsed.
    ///
    func load(from data: Data) throws -> D3.Node {
        guard let format = ModelFileFormat.detect(from: data) else {
            throw Error.unrecognizedFormat
        }

        let meshData: MeshData
        switch format {
        case .stlBinary:
            meshData = try loadBinary(from: data)
        case .stlASCII:
            meshData = try loadASCII(from: data)
        case .threeMF:
            throw Error.unrecognizedFormat
        }

        return D3.Node.shape(.mesh(meshData))
    }

    enum Error: Swift.Error {
        case unrecognizedFormat
        case invalidBinaryHeader
        case invalidTriangleCount
        case unexpectedEndOfData
        case invalidASCIISyntax(String)
    }
}

// MARK: - Binary STL

private extension STLLoader {
    /// Binary STL format:
    /// - 80 bytes: Header (ignored, may contain any text)
    /// - 4 bytes: Number of triangles (uint32, little-endian)
    /// - For each triangle (50 bytes each):
    ///   - 12 bytes: Normal vector (3 x float32)
    ///   - 12 bytes: Vertex 1 (3 x float32)
    ///   - 12 bytes: Vertex 2 (3 x float32)
    ///   - 12 bytes: Vertex 3 (3 x float32)
    ///   - 2 bytes: Attribute byte count (usually 0, ignored)
    ///
    func loadBinary(from data: Data) throws -> MeshData {
        guard data.count >= 84 else {
            throw Error.invalidBinaryHeader
        }

        let triangleCount = data.withUnsafeBytes { buffer in
            buffer.loadUnaligned(fromByteOffset: 80, as: UInt32.self).littleEndian
        }

        let expectedSize = 84 + Int(triangleCount) * 50
        guard data.count >= expectedSize else {
            throw Error.invalidTriangleCount
        }

        var vertices: [Vector3D] = []
        var faces: [[Int]] = []
        vertices.reserveCapacity(Int(triangleCount) * 3)
        faces.reserveCapacity(Int(triangleCount))

        // Using a dictionary to deduplicate vertices
        var vertexIndices: [Vector3D: Int] = [:]
        vertexIndices.reserveCapacity(Int(triangleCount) * 3)

        try data.withUnsafeBytes { buffer in
            var offset = 84

            for _ in 0..<triangleCount {
                // Skip the normal (12 bytes) - we'll compute normals from vertices if needed
                offset += 12

                var faceIndices: [Int] = []
                faceIndices.reserveCapacity(3)

                for _ in 0..<3 {
                    guard offset + 12 <= data.count else {
                        throw Error.unexpectedEndOfData
                    }

                    let x = Double(buffer.loadUnaligned(fromByteOffset: offset, as: Float32.self))
                    let y = Double(buffer.loadUnaligned(fromByteOffset: offset + 4, as: Float32.self))
                    let z = Double(buffer.loadUnaligned(fromByteOffset: offset + 8, as: Float32.self))
                    offset += 12

                    let vertex = Vector3D(x, y, z)

                    let index: Int
                    if let existingIndex = vertexIndices[vertex] {
                        index = existingIndex
                    } else {
                        index = vertices.count
                        vertices.append(vertex)
                        vertexIndices[vertex] = index
                    }
                    faceIndices.append(index)
                }

                faces.append(faceIndices)

                // Skip attribute byte count (2 bytes)
                offset += 2
            }
        }

        return MeshData(vertices: vertices, faces: faces)
    }
}

// MARK: - ASCII STL

private extension STLLoader {
    /// ASCII STL format:
    /// ```
    /// solid name
    ///   facet normal ni nj nk
    ///     outer loop
    ///       vertex v1x v1y v1z
    ///       vertex v2x v2y v2z
    ///       vertex v3x v3y v3z
    ///     endloop
    ///   endfacet
    /// endsolid name
    /// ```
    ///
    func loadASCII(from data: Data) throws -> MeshData {
        guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii) else {
            throw Error.invalidASCIISyntax("Unable to decode file as text")
        }

        var vertices: [Vector3D] = []
        var faces: [[Int]] = []
        var vertexIndices: [Vector3D: Int] = [:]

        var currentFaceVertices: [Int] = []
        var inLoop = false

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()

            if trimmed.hasPrefix("facet normal") || trimmed.hasPrefix("facet") {
                currentFaceVertices = []
            } else if trimmed == "outer loop" {
                inLoop = true
            } else if trimmed.hasPrefix("vertex ") {
                guard inLoop else { continue }

                let parts = trimmed.dropFirst(7).split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 3,
                      let x = Double(parts[0]),
                      let y = Double(parts[1]),
                      let z = Double(parts[2]) else {
                    throw Error.invalidASCIISyntax("Invalid vertex: \(line)")
                }

                let vertex = Vector3D(x, y, z)

                let index: Int
                if let existingIndex = vertexIndices[vertex] {
                    index = existingIndex
                } else {
                    index = vertices.count
                    vertices.append(vertex)
                    vertexIndices[vertex] = index
                }
                currentFaceVertices.append(index)
            } else if trimmed == "endloop" {
                inLoop = false
            } else if trimmed == "endfacet" {
                if currentFaceVertices.count >= 3 {
                    faces.append(currentFaceVertices)
                }
                currentFaceVertices = []
            }
        }

        return MeshData(vertices: vertices, faces: faces)
    }
}
