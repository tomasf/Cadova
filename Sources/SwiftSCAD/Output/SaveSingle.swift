import Foundation

public extension Geometry3D {
    /// Saves the 3D geometry to a specified URL.
    /// - Parameter url: The URL of the file to save the geometry to.
    func save(to url: URL) {
        AnyGeometry(self.usingDefaultFacets()).save(to: url)
    }

    /// Saves the 3D geometry to a specified path.
    /// - Parameter path: The path of the file to save the geometry to.
    func save(to path: String) {
        save(to: URL(expandingFilePath: path))
    }
}

public extension Geometry2D {
    /// Saves the 2D geometry to a specified URL.
    /// - Parameter url: The URL of the file to save the geometry to.
    func save(to url: URL) {
        AnyGeometry(self.usingDefaultFacets()).save(to: url)
    }

    /// Saves the 2D geometry to a specified path.
    /// - Parameter path: The path of the file to save the geometry to.
    func save(to path: String) {
        save(to: URL(expandingFilePath: path))
    }
}

internal extension AnyGeometry {
    func save(to url: URL) {
        let environment = EnvironmentValues.defaultEnvironment
        let (codeFragment, _, formats) = evaluated(in: environment)
        for format in formats {
            let finalURL = url.withRequiredExtension(format.fileExtension)
            codeFragment.save(to: finalURL, format: format)
        }
    }
}
