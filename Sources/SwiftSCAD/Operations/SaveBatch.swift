import Foundation

public func save(to directory: URL? = nil, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let effectiveEnvironment = environment ?? .defaultEnvironment
    let namedGeometry = NamedGeometry.merging(geometries().compactMap {
        $0.namedGeometry(in: effectiveEnvironment)
    })
    for (name, geometry) in namedGeometry.geometry.sorted(by: { $0.key < $1.key }) {
        let fileURL = URL(expandingFilePath: name, extension: "scad", relativeTo: directory)

        switch geometry {
        case .twoD (let geometry):
            geometry
                .usingDefaultFacets()
                .codeFragment(in: effectiveEnvironment)
                .export(to: fileURL)
        case .threeD (let geometry):
            geometry
                .usingDefaultFacets()
                .codeFragment(in: effectiveEnvironment)
                .export(to: fileURL)
        }
    }
}

public func save(to directory: String?, environment: Environment? = nil, @AnyGeometryBuilder geometries: () -> [AnyGeometry]) {
    let url = directory.map { URL(expandingFilePath: $0) }
    save(to: url, environment: environment, geometries: geometries)
}
