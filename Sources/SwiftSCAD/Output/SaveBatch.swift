import Foundation

public func save(to directory: URL? = nil, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let environment = environment ?? .defaultEnvironment

    for geometry in geometries() {
        let (name, formats) = geometry.results(in: environment)
        guard let name else {
            logger.warning("Found a geometry without a name. Use .named(_:) to assign names to geometry.")
            continue
        }

        let codeFragment = geometry.codeFragment(in: environment)
        for format in formats {
            let fileURL = URL(expandingFilePath: name, extension: format.fileExtension, relativeTo: directory)
            codeFragment.save(to: fileURL, format: format)
        }
    }
}

public func save(to directory: String?, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let url = directory.map { URL(expandingFilePath: $0) }
    save(to: url, environment: environment, geometries: geometries)
}

