import Foundation
import ThreeMF

struct MetadataContainer: ResultElement {
    private(set) var metadata: [ThreeMF.Metadata]

    init(metadata: [ThreeMF.Metadata] = []) {
        self.metadata = metadata
    }

    init() {
        self.init(metadata: [])
    }

    init(combining containers: [MetadataContainer]) {
        self.init(metadata: Array(containers.map(\.metadata).joined()))
    }

    mutating func add(_ name: ThreeMF.Metadata.Name, value: String) {
        metadata.append(.init(name: name, value: value))
    }

    func contains(_ name: ThreeMF.Metadata.Name) -> Bool {
        metadata.contains(where: { $0.name == name })
    }
}

/// Attaches metadata to the resulting 3MF file generated from this geometry.
///
/// Use this method to embed descriptive and attributional metadata in the 3MF output, such as the model's title,
/// author, license, or creation date. This metadata is stored in the 3MF file's metadata section and is readable
/// by slicers and 3D modeling tools that support 3MF metadata.
///
/// Any parameter that is `nil` will be ignored. This allows partial metadata without affecting other existing values.
public extension Geometry {
    func addingMetadata(
        title: String? = nil,
        designer: String? = nil,
        description: String? = nil,
        copyright: String? = nil,
        licenseTerms: String? = nil,
        rating: String? = nil,
        creationDate: String? = nil,
        modificationDate: String? = nil,
        application: String? = nil
    ) -> D.Geometry {
        modifyingResult(MetadataContainer.self) {
            if let title { $0.add(.title, value: title) }
            if let designer { $0.add(.designer, value: designer) }
            if let description { $0.add(.description, value: description) }
            if let copyright { $0.add(.copyright, value: copyright) }
            if let licenseTerms { $0.add(.licenseTerms, value: licenseTerms) }
            if let rating { $0.add(.rating, value: rating) }
            if let creationDate { $0.add(.creationDate, value: creationDate) }
            if let modificationDate { $0.add(.modificationDate, value: modificationDate) }
            if let application { $0.add(.application, value: application) }
        }
    }
}
