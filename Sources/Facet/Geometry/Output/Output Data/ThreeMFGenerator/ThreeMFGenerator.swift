import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct ThreeMF {
    let objects: [Object]
    let items: [Item]
    let colorGroups: [ColorGroup]
    let metadata: [Metadata]

    struct Object {
        let id: Int
        let type: String
        let name: String
        let mesh: Mesh
    }

    struct Mesh {
        let vertices: [Vector3D]
        let triangles: [Triangle]

        struct Triangle {
            let v1: Int
            let v2: Int
            let v3: Int
            let color: (group: Int, colorIndex: Int)?
        }
    }

    struct Item {
        let objectID: Int
        let printable: Bool?
    }

    struct ColorGroup {
        let id: Int
        let colors: [Color]
    }

    struct Metadata: Hashable {
        let name: Name
        let value: String

        enum Name: Hashable {
            case title
            case designer
            case description
            case copyright
            case licenseTerms
            case rating
            case creationDate
            case modificationDate
            case application
            case custom (String)

            var key: String {
                switch self {
                case .title: "Title"
                case .designer: "Designer"
                case .description: "Description"
                case .copyright: "Copyright"
                case .licenseTerms: "LicenseTerms"
                case .rating: "Rating"
                case .creationDate: "CreationDate"
                case .modificationDate: "ModificationDate"
                case .application: "Application"
                case .custom (let name): name
                }
            }
        }
    }

    // Cura is idiotically hard-coded to always read this file name, so keep this for compatibility
    let modelFilePath = "3D/3dmodel.model"
}
