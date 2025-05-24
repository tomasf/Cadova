import Foundation

internal extension EnvironmentValues {
    private static let key = Key("Cadova.ModelOptions")

    var modelOptions: ModelOptions? {
        get { self[Self.key] as? ModelOptions }
        set { self[Self.key] = newValue }
    }

    var outputSupportsParts: Bool {
        modelOptions?[ModelOptions.FileFormat3D.self] == .threeMF
    }
}

public extension EnvironmentValues {
    var modelName: String? {
        modelOptions?[ModelName.self].name
    }
}
