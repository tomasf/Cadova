import Foundation

internal extension EnvironmentValues {
    private static let parametersKey = Key("Cadova.Parameters")

    /// The parameter values a customizer chose, by label, as strings that each parameter parses as
    /// its own type.
    var parameterValues: [String: String] {
        get { self[Self.parametersKey] as? [String: String] ?? [:] }
        set { self[Self.parametersKey] = newValue }
    }

    /// Reads a parameter's value, or nil if no value was chosen or it isn't a valid value of the
    /// parameter's type.
    func parameterValue<V: ParameterValue>(_ label: String, as type: V.Type = V.self) -> V? {
        guard let string = parameterValues[label] else { return nil }
        guard let value = V(parameterString: string) else {
            logger.warning("The value \"\(string)\" for parameter \"\(label)\" could not be interpreted as \(V.self). Using the default value instead.")
            return nil
        }
        return value
    }

    /// The default environment plus the parameter values a customizer asked for, if one started the
    /// executable. Models start from this environment.
    static var rootEnvironment: EnvironmentValues {
        var environment = defaultEnvironment
        environment.parameterValues = CustomizerRequest.current?.values ?? [:]
        return environment
    }
}
