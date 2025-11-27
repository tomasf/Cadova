import Foundation

public extension ModelOptions {
    /// Sets the semantic roles of parts to include when exporting the model.
    ///
    /// By default, all parts are included for formats that support multiple parts,
    /// such as 3MF. For formats without this capability (e.g., STL), only `.solid` parts
    /// are included unless specified.
    ///
    /// - Parameter semantics: One or more semantic roles of parts to include in the output.
    /// - Returns: A `ModelOptions` value representing the selected included part semantics.
    static func partSemantics(_ semantics: PartSemantic...) -> Self {
        .init(IncludedPartSemantics(semantics: Set(semantics)))
    }

    /// A convenience option to include only `.solid` parts when exporting the model.
    static var solidPartsOnly: Self {
        .partSemantics(.solid)
    }

    /// Compression level options for 3MF model export.
    struct IncludedPartSemantics: Sendable, ModelOptionItem {
        let semantics: Set<PartSemantic>

        internal static let defaultValue = Self(semantics: [])
        internal func combined(with other: Self) -> Self {
            IncludedPartSemantics(semantics: semantics.union(other.semantics))
        }
    }
}

internal extension ModelOptions {
    func includedPartSemantics(for format: FileFormat3D) -> Set<PartSemantic> {
        let semantics = self[IncludedPartSemantics.self].semantics
        return semantics.isEmpty ? format.defaultIncludedPartSemantics : semantics
    }
}

fileprivate extension ModelOptions.FileFormat3D {
    var defaultIncludedPartSemantics: Set<PartSemantic> {
        switch self {
        case .threeMF: return Set(PartSemantic.allCases)
        case .stl: return [.solid]
        }
    }
}
