import Foundation

/// A property wrapper that makes a value adjustable in a web customizer.
///
/// Give each parameter a label and a default value. A customizer page, which
/// `swift package generate-customizer` builds, shows a control for every parameter a model has,
/// labelled with the label, and builds the model with the values its visitor chooses. Everywhere
/// else, such as when you build the model yourself, a parameter has its default value.
///
/// We recommend declaring parameters in the model, and passing their values to your geometry:
///
/// ```swift
/// await Model("plate") {
///     @Parameter("Columns", in: 1...12) var columns = 4
///     @Parameter("Height", in: 10...50, step: 0.5, unit: "mm", description: "Height of the plate")
///     var height = 20.0
///
///     GridPlate(columns: columns, height: height)
/// }
/// ```
///
/// A parameter is identified by where it's declared, so every use of the same declaration shares its
/// value, while separate declarations are separate parameters, even with the same label. Each model
/// keeps its own values.
///
/// Parameters can be declared anywhere in a model's code, such as in a geometry's `body` or as a
/// property of a geometry type. A property is one parameter however many instances there are, so
/// `GridPlate(columns: 3)` and `GridPlate(columns: 6)` share a single control. Cadova logs a warning
/// when uses of one parameter have different defaults or settings.
///
/// Read parameters inside a model: in a geometry's `body`, a `Model { }` builder or another geometry
/// callback. A parameter read outside any model has its default value.
///
/// Supported types include `Int`, `Double`, `Bool`, `String`, `Angle`, ``Color``, and ``ParameterChoice`` enums;
/// see ``ParameterValue`` for details.
///
/// To make and publish a customizer, see <doc:WebCustomizer>.
///
@propertyWrapper public struct Parameter<Value: ParameterValue>: Sendable {
    /// What a customizer calls the parameter.
    let label: String

    /// Identifies the parameter within its model: where it's declared, and its label, since a
    /// declaration in a function can be given different labels. Customizers treat it as opaque.
    internal let key: String

    /// The value the parameter has unless a customizer chooses another.
    let defaultValue: Value

    /// A short explanation of what the parameter controls, shown by customizers.
    let description: String?

    /// The smallest value a customizer offers, if the parameter has a range.
    let minimum: Value?

    /// The largest value a customizer offers, if the parameter has a range.
    let maximum: Value?

    /// The increment a customizer steps the value by, if any.
    let step: Value?

    /// What a customizer shows after a number, such as `"mm"` or `"pcs"`, if anything.
    let unit: String?

    /// Creates a parameter with a label and a default value.
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value.
    ///   - label: What a customizer calls the parameter.
    ///   - description: A short explanation of what the parameter controls, shown by customizers.
    ///   - fileID: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - line: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - column: Where the parameter is declared, which identifies it. Leave this at its default.
    public init(
        wrappedValue: Value,
        _ label: String,
        description: String? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) {
        self.init(label: label, defaultValue: wrappedValue, description: description, minimum: nil, maximum: nil, step: nil,
                  unit: nil, key: ParameterDescriptor.key(label: label, fileID: fileID, line: line, column: column))
    }

    /// Creates a parameter with a label, a default value and a range for customizers to offer.
    ///
    /// ```swift
    /// @Parameter("Height", in: 10...50, step: 0.5, description: "Height of the plate")
    /// var height = 20.0
    /// ```
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value.
    ///   - label: What a customizer calls the parameter.
    ///   - range: The values a customizer offers.
    ///   - step: The increment a customizer steps the value by.
    ///   - description: A short explanation of what the parameter controls, shown by customizers.
    ///   - fileID: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - line: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - column: Where the parameter is declared, which identifies it. Leave this at its default.
    public init(
        wrappedValue: Value,
        _ label: String,
        in range: ClosedRange<Value>,
        step: Value? = nil,
        description: String? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) where Value: Comparable {
        self.init(label: label, defaultValue: wrappedValue, description: description,
                  minimum: range.lowerBound, maximum: range.upperBound, step: step, unit: nil,
                  key: ParameterDescriptor.key(label: label, fileID: fileID, line: line, column: column))
    }

    /// Creates a number parameter with a label, a default value and a unit that customizers show
    /// after it.
    ///
    /// ```swift
    /// @Parameter("Count", unit: "pcs") var count = 4
    /// ```
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value.
    ///   - label: What a customizer calls the parameter.
    ///   - unit: What a customizer shows after the number, such as `"mm"` or `"pcs"`.
    ///   - description: A short explanation of what the parameter controls, shown by customizers.
    ///   - fileID: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - line: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - column: Where the parameter is declared, which identifies it. Leave this at its default.
    public init(
        wrappedValue: Value,
        _ label: String,
        unit: String,
        description: String? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) where Value: NumericParameterValue {
        self.init(label: label, defaultValue: wrappedValue, description: description, minimum: nil, maximum: nil, step: nil,
                  unit: unit, key: ParameterDescriptor.key(label: label, fileID: fileID, line: line, column: column))
    }

    /// Creates a number parameter with a label, a default value, a range for customizers to offer
    /// and a unit they show after it.
    ///
    /// ```swift
    /// @Parameter("Height", in: 10...50, step: 0.5, unit: "mm", description: "Height of the plate")
    /// var height = 20.0
    /// ```
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value.
    ///   - label: What a customizer calls the parameter.
    ///   - range: The values a customizer offers.
    ///   - step: The increment a customizer steps the value by.
    ///   - unit: What a customizer shows after the number, such as `"mm"` or `"pcs"`.
    ///   - description: A short explanation of what the parameter controls, shown by customizers.
    ///   - fileID: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - line: Where the parameter is declared, which identifies it. Leave this at its default.
    ///   - column: Where the parameter is declared, which identifies it. Leave this at its default.
    public init(
        wrappedValue: Value,
        _ label: String,
        in range: ClosedRange<Value>,
        step: Value? = nil,
        unit: String,
        description: String? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) where Value: NumericParameterValue {
        self.init(label: label, defaultValue: wrappedValue, description: description,
                  minimum: range.lowerBound, maximum: range.upperBound, step: step, unit: unit,
                  key: ParameterDescriptor.key(label: label, fileID: fileID, line: line, column: column))
    }

    private init(
        label: String, defaultValue: Value, description: String?, minimum: Value?, maximum: Value?, step: Value?,
        unit: String?, key: String
    ) {
        self.label = label
        self.key = key
        self.defaultValue = defaultValue
        self.description = description
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.unit = unit
        ParameterRecorder.current?.record(descriptor)
    }

    public var wrappedValue: Value {
        ParameterRecorder.current?.record(descriptor)
        return EnvironmentValues.current.parameterValue(key, label: label) ?? defaultValue
    }

    /// The parameter's value in an environment: the one a customizer chose, or the default.
    internal func value(in environment: EnvironmentValues) -> Value {
        environment.parameterValues[key].flatMap(Value.init(parameterString:)) ?? defaultValue
    }

    internal var descriptor: ParameterDescriptor {
        ParameterDescriptor(
            key: key,
            label: label,
            kind: ParameterKind(Value.self),
            defaultValue: defaultValue.parameterString,
            minimum: minimum?.parameterString,
            maximum: maximum?.parameterString,
            step: step?.parameterString,
            unit: unit,
            description: description
        )
    }
}

// A `CachedGeometry` with a parameter is cached by the parameter's current value, so that choosing
// another value builds it again
extension Parameter: _EnvironmentCacheKeyReadable {
    func cacheKeyValue(in environment: EnvironmentValues) -> AnyCacheKey {
        AnyCacheKey(value(in: environment).parameterString)
    }
}
