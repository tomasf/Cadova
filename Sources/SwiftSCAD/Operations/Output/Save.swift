import Foundation

fileprivate extension Geometry {
    func save(to fileURL: URL, using environment: Environment) {
        do {
            let string = self.scadString(in: environment)
            try string.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            preconditionFailure("Failed to write to file \(fileURL)")
        }
    }

    func save(to path: String, using environment: Environment) {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        save(to: url, using: environment)
    }
}

public extension Geometry3D {
    @discardableResult func save(to path: String) -> Geometry3D {
        self.usingDefaultFacets().save(to: path, using: Environment())
        return self
    }

    @discardableResult func save(to url: URL) -> Geometry3D {
        self.usingDefaultFacets().save(to: url, using: Environment())
        return self
    }
}

public extension Geometry2D {
    @discardableResult func save(to path: String) -> Geometry2D {
        self.usingDefaultFacets().save(to: path, using: Environment())
        return self
    }

    @discardableResult func save(to url: URL) -> Geometry2D {
        self.usingDefaultFacets().save(to: url, using: Environment())
        return self
    }
}
