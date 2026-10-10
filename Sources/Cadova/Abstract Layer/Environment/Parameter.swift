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
/// The label also identifies the parameter within its model, so parameters with the same label in
/// one model are one parameter, with one control. Different models keep their own values, even for
/// parameters with the same label.
///
/// Read parameters inside a model: in a geometry's `body`, a `Model { }` builder or another geometry
/// callback. A parameter read outside any model has its default value.
///
/// Supported types include `Int`, `Double`, `Bool`, `String`, `Angle`, and string-backed enums;
/// see ``ParameterValue`` for details.
///
@propertyWrapper public struct Parameter<Value: ParameterValue>: Sendable {
    /// What a customizer calls the parameter, which also identifies it within its model.
    public let label: String

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
    public init(wrappedValue: Value, _ label: String, description: String? = nil) {
        self.init(label: label, defaultValue: wrappedValue, description: description, minimum: nil, maximum: nil, step: nil)
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
    public init(
        wrappedValue: Value,
        _ label: String,
        in range: ClosedRange<Value>,
        step: Value? = nil,
        description: String? = nil
    ) where Value: Comparable {
        self.init(label: label, defaultValue: wrappedValue, description: description,
                  minimum: range.lowerBound, maximum: range.upperBound, step: step)
    }

    private init(label: String, defaultValue: Value, description: String?, minimum: Value?, maximum: Value?, step: Value?) {
        self.label = label
        self.defaultValue = defaultValue
        self.description = description
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        ParameterRecorder.current?.record(descriptor)
    }

    public var wrappedValue: Value {
        ParameterRecorder.current?.record(descriptor)
        return EnvironmentValues.current.parameterValue(label) ?? defaultValue
    }

    internal var descriptor: ParameterDescriptor {
        ParameterDescriptor(
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
