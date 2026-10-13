import Foundation

/// A property wrapper that makes a value adjustable in a web customizer.
///
/// Give each parameter a label and a default value. A customizer page, which
/// `swift package generate-customizer` builds, shows a control for every parameter a model has,
/// labelled with the label, and builds the model with the values its visitor chooses. Everywhere
/// else, such as when you build the model yourself, a parameter has its default value.
///
/// ```swift
/// struct GridPlate: Geometry3D {
///     @Parameter("Columns", in: 1...12) var columns = 4
///     @Parameter("Height", in: 10...50, step: 0.5, description: "Height of the plate, in millimeters")
///     var height = 20.0
///
///     var body: any Geometry3D {
///         ...
///     }
/// }
/// ```
///
/// A parameter is identified by where it's declared, so every geometry that uses the same declaration
/// shares its value, while separate declarations are separate parameters, even with the same label.
/// Each model keeps its own values.
///
/// Read parameters inside a model: in a geometry's `body`, a `Model { }` builder or another geometry
/// callback. A parameter read outside any model has its default value.
///
/// Supported types include `Int`, `Double`, `Bool`, `String`, `Angle`, and string-backed enums;
/// see ``ParameterValue`` for details.
///
/// To make and publish a customizer, see <doc:WebCustomizer>.
///
@propertyWrapper public struct Parameter<Value: ParameterValue>: Sendable {
    /// What a customizer calls the parameter.
    public let label: String

    /// Identifies the parameter within its model: where it's declared, and its label, since a
    /// declaration in a function can be given different labels. Customizers treat it as opaque.
    internal let key: String

    /// The value the parameter has unless a customizer chooses another.
    public let defaultValue: Value

    /// A short explanation of what the parameter controls, shown by customizers.
    public let description: String?

    /// The smallest value a customizer offers, if the parameter has a range.
    public let minimum: Value?

    /// The largest value a customizer offers, if the parameter has a range.
    public let maximum: Value?

    /// The increment a customizer steps the value by, if any.
    public let step: Value?

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
                  key: ParameterDescriptor.key(label: label, fileID: fileID, line: line, column: column))
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
                  minimum: range.lowerBound, maximum: range.upperBound, step: step,
                  key: ParameterDescriptor.key(label: label, fileID: fileID, line: line, column: column))
    }

    private init(label: String, defaultValue: Value, description: String?, minimum: Value?, maximum: Value?, step: Value?, key: String) {
        self.label = label
        self.key = key
        self.defaultValue = defaultValue
        self.description = description
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        ParameterRecorder.current?.record(descriptor)
    }

    public var wrappedValue: Value {
        ParameterRecorder.current?.record(descriptor)
        return EnvironmentValues.current.parameterValue(key, label: label) ?? defaultValue
    }

    internal var descriptor: ParameterDescriptor {
        ParameterDescriptor(
            key: key,
            label: label,
            kind: Value.parameterKind,
            defaultValue: defaultValue.parameterString,
            minimum: minimum?.parameterString,
            maximum: maximum?.parameterString,
            step: step?.parameterString,
            description: description
        )
    }
}
