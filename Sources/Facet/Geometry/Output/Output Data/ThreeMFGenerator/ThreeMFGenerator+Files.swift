import Foundation
import Zip
#if canImport(FoundationXML)
import FoundationXML
#endif

extension ThreeMF {
    func generateData() throws -> Data {
        let archive = MemoryZipArchive()

        archive.addFile(name: "[Content_Types].xml", data: contentTypesFile)
        archive.addFile(name: "_rels/.rels", data: relationshipsFile)
        archive.addFile(name: modelFilePath, data: modelFile)

        return try archive.finalize()
    }

    private var modelFile: Data {
        let resources = XMLElement(name: "resources")
        resources.addChildren(colorGroups.map(\.xmlElement))
        resources.addChildren(objects.map(\.xmlElement))

        let build = XMLElement(name: "build")
        build.addChildren(items.map(\.xmlElement))

        let model = XMLElement(name: "model")
        model["xmlns"] = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
        model["xmlns:m"] = "http://schemas.microsoft.com/3dmanufacturing/material/2015/02"
        model["xml:lang"] = "en-US"
        model["unit"] = "millimeter"
        model.addChild(resources)
        model.addChild(build)

        model.addChildren(metadata.map(\.xmlElement))

        let document = XMLDocument(rootElement: model)
        return document.xmlData(options: .nodeCompactEmptyElement)
    }

    private var contentTypesFile: Data {
        let types = XMLElement(name: "Types")
        types["xmlns"] = "http://schemas.openxmlformats.org/package/2006/content-types"

        let defaultElement = XMLElement(name: "Default")
        defaultElement["ContentType"] = "application/vnd.ms-package.3dmanufacturing-3dmodel+xml"
        defaultElement["Extension"] = "model"
        types.addChild(defaultElement)

        let document = XMLDocument(rootElement: types)
        return document.xmlData(options: .nodeCompactEmptyElement)
    }

    private var relationshipsFile: Data {
        let relationships = XMLElement(name: "Relationships")
        relationships["xmlns"] = "http://schemas.openxmlformats.org/package/2006/relationships"

        let relationship = XMLElement(name: "Relationship")
        relationship["Target"] = "/" + modelFilePath
        relationship["Id"] = "rel0"
        relationship["Type"] = "http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"
        relationships.addChild(relationship)

        let document = XMLDocument(rootElement: relationships)
        return document.xmlData(options: .nodeCompactEmptyElement)
    }
}
