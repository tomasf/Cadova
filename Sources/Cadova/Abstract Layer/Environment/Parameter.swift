import Foundation

/// A property wrapper for reading customizer parameters.
///
/// Parameters make a model configurable from the outside without editing its source code. Each
/// parameter has a name and a default value. When the model is built, the value can be overridden
/// from the command line:
///
/// ```
/// $ my-model --param count=8 --param height=25.5
/// ```
///
/// ## Usage
/// ```swift
/// struct GridPlate: Geometry3D {
///     @Parameter("columns") var columns = 4
///     @Parameter("height") var height = 20.0
///
///     var body: any Geometry3D {
///         ...
///     }
/// }
/// ```
///
/// Parameter values flow through the environment, so they can also be overridden
/// programmatically for a subtree using ``Geometry/withParameter(_:_:)``, or set with
/// ``EnvironmentValues/settingParameter(_:to:)``. Command line values apply at the root of
/// the model; like all environment values, more local settings win, so a value set in code
/// takes precedence over one from the command line.
///
/// Because parameters are resolved from the active environment, they must be read inside a
/// model context — within a `Model { }` builder, a geometry's `body`, or another geometry
/// callback. A parameter read outside any model returns its default value.
///
/// Supported types include `Int`, `Double`, `Bool`, `String`, `Angle`, and string-backed enums;
/// see ``ParameterValue`` for details. If a command line value fails to parse as the parameter's
/// type, a warning is logged and the default value is used.
///
@propertyWrapper public struct Parameter<Value: ParameterValue>: Sendable {
    /// The name used to identify this parameter, e.g. on the command line.
    public let name: String

    /// The value used when the environment provides no valid value for this parameter.
    public let defaultValue: Value

    /// A short explanation of what the parameter controls, shown by customizers.
    public let description: String?

    /// The smallest value a customizer offers, if the parameter has a range.
    public let minimum: Value?

    /// The largest value a customizer offers, if the parameter has a range.
    public let maximum: Value?

    /// The increment a customizer steps the value by, if any.
    public let step: Value?

    /// Creates a parameter with a name and a default value.
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value, used when the parameter is not set.
    ///   - name: The name of the parameter, as used on the command line (`--param name=value`).
    ///   - description: A short explanation of what the parameter controls, shown by customizers.
    public init(wrappedValue: Value, _ name: String, description: String? = nil) {
        self.init(name: name, defaultValue: wrappedValue, description: description, minimum: nil, maximum: nil, step: nil)
    }

    /// Creates a parameter with a name, a default value and a range for customizers to offer.
    ///
    /// The range describes the values that make sense for the parameter, so that a customizer can
    /// offer a slider or reject values outside it. Values set in code or on the command line are
    /// used as given, even outside the range.
    ///
    /// ```swift
    /// @Parameter("height", in: 10...50, step: 0.5, description: "Height of the plate")
    /// var height = 20.0
    /// ```
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value, used when the parameter is not set.
    ///   - name: The name of the parameter, as used on the command line (`--param name=value`).
    ///   - range: The values a customizer offers.
    ///   - step: The increment a customizer steps the value by.
    ///   - description: A short explanation of what the parameter controls, shown by customizers.
    public init(
        wrappedValue: Value,
        _ name: String,
        in range: ClosedRange<Value>,
        step: Value? = nil,
        description: String? = nil
    ) where Value: Comparable {
        self.init(name: name, defaultValue: wrappedValue, description: description,
                  minimum: range.lowerBound, maximum: range.upperBound, step: step)
    }

    private init(name: String, defaultValue: Value, description: String?, minimum: Value?, maximum: Value?, step: Value?) {
        self.name = name
        self.defaultValue = defaultValue
        self.description = description
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        ParameterRecorder.current?.record(descriptor)
    }

    public var wrappedValue: Value {
        ParameterRecorder.current?.record(descriptor)
        return EnvironmentValues.current.parameterValue(name) ?? defaultValue
    }

    /// The parameter itself, providing access to its metadata (``name``, ``defaultValue``,
    /// ``isOverridden``) via the `$` prefix.
    public var projectedValue: Parameter<Value> { self }

    /// Whether the active environment provides a valid value for this parameter.
    public var isOverridden: Bool {
        EnvironmentValues.current.parameterValue(name, as: Value.self) != nil
    }

    internal var descriptor: ParameterDescriptor {
        ParameterDescriptor(
            name: name,
            kind: Value.parameterKind,
            defaultValue: defaultValue.parameterString,
            minimum: minimum?.parameterString,
            maximum: maximum?.parameterString,
            step: step?.parameterString,
            description: description
        )
    }
}
