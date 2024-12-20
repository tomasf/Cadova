import Foundation

struct MetadataContainer: ResultElement {
    let metadata: [ThreeMF.Metadata]

    init(metadata: [ThreeMF.Metadata] = []) {
        self.metadata = metadata
    }

    init(name: ThreeMF.Metadata.Name, value: String) {
        self.init(metadata: [.init(name: name, value: value)])
    }

    func adding(_ name: ThreeMF.Metadata.Name, value: String) -> Self {
        MetadataContainer(metadata: metadata + [.init(name: name, value: value)])
    }

    static func combine(elements: [Self], for operation: GeometryCombination) -> Self? {
        MetadataContainer(metadata: Array(elements.map(\.metadata).joined()))
    }
}

// Adds metadata to the resulting 3MF file
public extension Geometry3D {
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
    ) -> any Geometry3D {
        modifyingResult(MetadataContainer.self) {
            var container = $0 ?? .init(metadata: [])
            if let title { container = container.adding(.title, value: title) }
            if let designer { container = container.adding(.designer, value: designer) }
            if let description { container = container.adding(.description, value: description) }
            if let copyright { container = container.adding(.copyright, value: copyright) }
            if let licenseTerms { container = container.adding(.licenseTerms, value: licenseTerms) }
            if let rating { container = container.adding(.rating, value: rating) }
            if let creationDate { container = container.adding(.creationDate, value: creationDate) }
            if let modificationDate { container = container.adding(.modificationDate, value: modificationDate) }
            if let application { container = container.adding(.application, value: application) }
            return container
        }
    }
}
