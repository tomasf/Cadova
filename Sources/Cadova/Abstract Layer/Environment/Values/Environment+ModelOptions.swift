import Foundation

internal extension EnvironmentValues {
    private static let key = Key("Cadova.ModelOptions")

    var modelOptions: ModelOptions? {
        get { self[Self.key] as? ModelOptions }
        set { self[Self.key] = newValue }
    }

    func outputIncludesSemantic(_ partSemantic: PartSemantic) -> Bool {
        let format = modelOptions?[ModelOptions.FileFormat3D.self] ?? .threeMF
        return modelOptions?.includedPartSemantics(for: format).contains(partSemantic) == true
    }

    var outputIncludesVisualSemantic: Bool {
        outputIncludesSemantic(.visual)
    }
}

public extension EnvironmentValues {
    var modelName: String? {
        modelOptions?[ModelName.self].name
    }
}
