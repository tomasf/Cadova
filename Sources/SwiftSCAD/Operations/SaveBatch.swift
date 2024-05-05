import Foundation

public typealias SaveMemberBuilder = ArrayBuilder<SaveMember>

public struct SaveMember {
    fileprivate let name: String
    fileprivate let evaluation: (Environment) -> Data
}

public extension Geometry2D {
    func named(_ name: String) -> SaveMember {
        SaveMember(name: name) { self.usingDefaultFacets().output(in: $0).scadData }
    }
}

public extension Geometry3D {
    func named(_ name: String) -> SaveMember {
        SaveMember(name: name) { self.usingDefaultFacets().output(in: $0).scadData }
    }
}

public func save(to directory: URL? = nil, environment: Environment? = nil, @SaveMemberBuilder geometries: () -> [SaveMember]) {
    for geometry in geometries() {
        let data = geometry.evaluation(environment ?? .defaultEnvironment)
        let fileURL = URL(expandingFilePath: geometry.name, extension: "scad", relativeTo: directory)
        try! data.write(to: fileURL)
        logger.info("Wrote output to \(fileURL.path)")
    }
}

public func save(to directory: String? = nil, environment: Environment? = nil, @SaveMemberBuilder geometries: () -> [SaveMember]) {
    let url = directory.map { URL(expandingFilePath: $0) }
    save(to: url, environment: environment, geometries: geometries)
}
