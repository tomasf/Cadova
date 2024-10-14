import Foundation

public func save(to directory: URL? = nil, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let effectiveEnvironment = environment ?? .defaultEnvironment
    let namedGeometry = NamedGeometry.merging(geometries().compactMap {
        $0.namedGeometry(in: effectiveEnvironment)
    })

    guard namedGeometry.geometry.count > 0 else {
        logger.warning("No named geometries to save. Use .named(_:) to assign names to geometry.")
        return
    }

    for (name, geometry) in namedGeometry.geometry.sorted(by: { $0.key < $1.key }) {
        let targetFormats = geometry.outputFormats(in: effectiveEnvironment)
        for format in targetFormats {
            let fileURL = URL(expandingFilePath: name, extension: format.fileExtension, relativeTo: directory)
            let codeFragment = geometry.codeFragment(in: effectiveEnvironment)
            codeFragment.save(to: fileURL, format: format)
        }
    }
}

public func save(to directory: String?, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let url = directory.map { URL(expandingFilePath: $0) }
    save(to: url, environment: environment, geometries: geometries)
}

