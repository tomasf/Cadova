import Testing
import Foundation
@testable import Cadova

extension URL {
    init(goldenFileNamed name: String, extension fileExtension: String) throws {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension,subdirectory: "golden") else {
            fatalError("Golden file \(name).\(fileExtension) not found")
        }
        self = url
    }
}

extension GeometryExpression {
    init(goldenFile fileName: String) throws {
        let data = try Data(contentsOf: URL(goldenFileNamed: fileName, extension: "json"))
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    var jsonData: Data {
        get throws {
            try JSONEncoder().encode(self)
        }
    }
}
