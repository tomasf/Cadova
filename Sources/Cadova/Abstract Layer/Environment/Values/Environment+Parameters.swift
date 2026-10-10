import Foundation

internal enum ParameterStorage: Sendable {
    /// An unparsed string, as provided on the command line. Parsed lazily against the type
    /// requested by the reader.
    case raw (String)
    /// A typed value set programmatically.
    case typed (any Sendable)
}

public extension EnvironmentValues {
    private static let parametersKey = Key("Cadova.Parameters")

    internal var parameters: [String: ParameterStorage] {
        get { self[Self.parametersKey] as? [String: ParameterStorage] ?? [:] }
        set { self[Self.parametersKey] = newValue }
    }

    /// Reads a customizer parameter from the environment, converting it to the requested type.
    ///
    /// Values that were provided as strings (from the command line) are parsed using the type's
    /// ``ParameterValue/init(parameterString:)``. Values set programmatically must match the
    /// requested type. In either case, a mismatch logs a warning and returns `nil`.
    ///
    /// - Parameters:
    ///   - name: The name of the parameter.
    ///   - type: The type to convert the value to.
    /// - Returns: The parameter value, or `nil` if the parameter is unset or could not be
    ///   converted to the requested type.
    ///
    func parameterValue<V: ParameterValue>(_ name: String, as type: V.Type = V.self) -> V? {
        switch parameters[name] {
        case .raw (let string):
            guard let parsed = V(parameterString: string) else {
                logger.warning("The value \"\(string)\" for parameter \"\(name)\" could not be interpreted as \(V.self). Using the default value instead.")
                return nil
            }
            return parsed

        case .typed (let value):
            guard let cast = value as? V else {
                logger.warning("Parameter \"\(name)\" holds a value of type \(Swift.type(of: value)), but was read as \(V.self). Using the default value instead.")
                return nil
            }
            return cast

        case nil:
            return nil
        }
    }

    /// Sets a customizer parameter in the environment.
    ///
    /// - Parameters:
    ///   - name: The name of the parameter.
    ///   - value: The new value, or `nil` to remove the parameter.
    mutating func setParameter<V: ParameterValue>(_ name: String, to value: V?) {
        parameters[name] = value.map { .typed($0) }
    }

    /// Returns a modified environment with a customizer parameter set.
    ///
    /// - Parameters:
    ///   - name: The name of the parameter.
    ///   - value: The new value, or `nil` to remove the parameter.
    /// - Returns: A new environment with the updated parameter.
    func settingParameter<V: ParameterValue>(_ name: String, to value: V?) -> EnvironmentValues {
        var environment = self
        environment.setParameter(name, to: value)
        return environment
    }

    internal func settingRawParameters(_ raw: [String: String]) -> EnvironmentValues {
        guard raw.isEmpty == false else { return self }
        var environment = self
        environment.parameters.merge(raw.mapValues { .raw($0) }) { $1 }
        return environment
    }
}

internal extension EnvironmentValues {
    /// The default environment plus any parameter overrides from the command line.
    /// Used as the root environment for standalone models.
    static var rootEnvironment: EnvironmentValues {
        defaultEnvironment.settingRawParameters(CommandLineArguments.current.parameters)
    }
}

public extension Geometry {
    /// Overrides a customizer parameter for this geometry.
    ///
    /// Any ``Parameter`` with the given name that is read within this geometry's subtree
    /// resolves to the specified value, taking precedence over values from the command line
    /// and from enclosing scopes. This lets you reuse a parameterized component with different
    /// values in different places:
    ///
    /// ```swift
    /// GridPlate()
    /// GridPlate().withParameter("columns", 8)
    ///     .translated(y: 60)
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name of the parameter to override.
    ///   - value: The value to use within this geometry.
    /// - Returns: A new geometry with the parameter override applied.
    ///
    func withParameter<V: ParameterValue>(_ name: String, _ value: V) -> D.Geometry {
        withEnvironment { $0.settingParameter(name, to: value) }
    }
}
