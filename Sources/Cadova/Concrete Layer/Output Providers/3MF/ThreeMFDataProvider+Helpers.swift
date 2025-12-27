import Foundation
import Manifold3D
internal import ThreeMF
internal import Zip
internal import Nodal

struct TriangleOIDMapping {
    private typealias Entry = (range: Range<Int>, originalID: Manifold.OriginalID)
    private let sortedEntries: [Entry]

    init(indexSets: [Manifold.OriginalID: IndexSet]) {
        var entries: [Entry] = []
        for (originalID, indexSet) in indexSets {
            for range in indexSet.rangeView {
                entries.append((range, originalID))
            }
        }
        entries.sort(by: { $0.range.lowerBound < $1.range.lowerBound })
        self.sortedEntries = entries
    }

    func originalID(for triangleIndex: Int) -> Manifold.OriginalID? {
        for (range, originalID) in sortedEntries {
            if range.lowerBound > triangleIndex {
                return nil
            }
            if range.upperBound > triangleIndex {
                return originalID
            }
        }
        return nil
    }
}

extension Metadata {
    var threeMFMetadata: [ThreeMF.Metadata] {
        [
            title.map { .init(name: .title, value: $0) },
            description.map { .init(name: .description, value: $0) },
            author.map { .init(name: .designer, value: $0) },
            license.map { .init(name: .licenseTerms, value: $0) },
            date.map { .init(name: .creationDate, value: $0) },
            application.map { .init(name: .application, value: $0) }
        ].compactMap { $0 }
    }
}

extension ModelOptions.Compression {
    var zipCompression: Zip.CompressionLevel {
        switch self {
        case .standard: return .default
        case .fastest: return .fastest
        case .smallest: return .best
        }
    }
}

fileprivate extension ExpandedName {
    static let semantic = CadovaNamespace.semantic
    // Prusa (?) extension
    static let printable = ExpandedName(namespaceName: nil, localName: "printable")
}

struct CadovaNamespace {
    static let uri = "https://cadova.org/3mf"
    fileprivate static let semantic = ExpandedName(namespaceName: uri, localName: "semantic")
}

fileprivate extension PartSemantic {
    init?(xmlAttributeValue value: String) {
        self.init(rawValue: value)
    }

    var xmlAttributeValue: String { rawValue }
}

extension ThreeMF.Item {
    var printable: Bool? {
        get {
            customAttributes[.printable].flatMap { try? Bool(xmlStringValue: $0) }
        }
        set {
            customAttributes[.printable] = newValue.map { $0 ? "1" : "0" }
        }
    }

    var semantic: PartSemantic? {
        get {
            customAttributes[.semantic].flatMap(PartSemantic.init(xmlAttributeValue:))
        }
        set {
            customAttributes[.semantic] = newValue?.xmlAttributeValue
        }
    }
}

extension GeometryNode<D3> {
    func deconstructTransform() -> (Self, Transform3D?) {
        if case .transform (let node, let transform) = contents {
            (node, transform)
        } else {
            (self, nil)
        }
    }
}

extension Transform3D {
    var matrix3D: Matrix3D {
        Matrix3D(values: (0..<4).map { column in
            (0..<3).map { row in
                self[row, column]
            }
        })
    }
}
