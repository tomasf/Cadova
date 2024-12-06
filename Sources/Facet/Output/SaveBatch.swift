import Foundation

public func save(to directory: URL? = nil, environment: EnvironmentValues? = nil, @GeometryProxyBuilder geometries: () -> [GeometryProxy]) {
    let environment = environment ?? .defaultEnvironment

    geometries().concurrentForEach { geometry in
        let (codeFragment, name, formats) = geometry.evaluated(in: environment)
        guard let name else {
            logger.warning("Found a geometry without a name. Use .named(_:) to assign names to geometry.")
            return
        }

        for format in formats {
            let fileURL = URL(expandingFilePath: name, extension: format.fileExtension, relativeTo: directory)
            codeFragment.save(to: fileURL, format: format)
        }
    }
}

public func save(to directory: String?, environment: EnvironmentValues? = nil, @GeometryProxyBuilder geometries: () -> [GeometryProxy]) {
    let url = directory.map { URL(expandingFilePath: $0) }
    save(to: url, environment: environment, geometries: geometries)
}

