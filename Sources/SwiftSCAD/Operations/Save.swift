import Foundation

extension GeometryOutput {
    func save(to fileURL: URL) {
        do {
            try scadCode.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("Wrote output to \(fileURL.path)")
        } catch {
            preconditionFailure("Failed to write to file \(fileURL)")
        }
    }

    func save(to path: String) {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        save(to: url)
    }
}


public extension Geometry3D {
    /// Saves the 3D geometry to a specified path.
    /// - Parameter path: The path of the file to save the geometry to.
    @discardableResult func save(to path: String) -> any Geometry3D {
        usingDefaultFacets()
            .output(in: .defaultEnvironment).save(to: path)
        return self
    }

    /// Saves the 3D geometry to a specified URL.
    /// - Parameter url: The URL of the file to save the geometry to.
    @discardableResult func save(to url: URL) -> any Geometry3D {
        usingDefaultFacets()
            .output(in: .defaultEnvironment).save(to: url)
        return self
    }
}

public extension Geometry2D {
    /// Saves the 2D geometry to a specified path.
    /// - Parameter path: The path of the file to save the geometry to.
    @discardableResult func save(to path: String) -> any Geometry2D {
        usingDefaultFacets()
            .output(in: .defaultEnvironment).save(to: path)
        return self
    }

    /// Saves the 2D geometry to a specified URL.
    /// - Parameter url: The URL of the file to save the geometry to.
    @discardableResult func save(to url: URL) -> any Geometry2D {
        usingDefaultFacets()
            .output(in: .defaultEnvironment).save(to: url)
        return self
    }
}
