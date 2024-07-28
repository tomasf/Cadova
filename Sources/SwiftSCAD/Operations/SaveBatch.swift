import Foundation

public func save(to directory: URL? = nil, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let effectiveEnvironment = environment ?? .defaultEnvironment
    let namedGeometry = NamedGeometry.merging(geometries().map {
        $0.output(in: effectiveEnvironment).namedGeometry
    })
    for (name, geometry) in namedGeometry {
        let fileURL = URL(expandingFilePath: name, extension: "scad", relativeTo: directory)

        switch geometry {
        case .twoD (let geometry):
            geometry
                .usingDefaultFacets()
                .output(in: effectiveEnvironment)
                .export(to: fileURL)
        case .threeD (let geometry):
            geometry
                .usingDefaultFacets()
                .output(in: effectiveEnvironment)
                .export(to: fileURL)
        }
    }
}

public func save(to directory: String?, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let url = directory.map { URL(expandingFilePath: $0) }
    save(to: url, environment: environment, geometries: geometries)
}
