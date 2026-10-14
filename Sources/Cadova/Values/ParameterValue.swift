import Foundation

/// A type that can be used as a customizer parameter value.
///
/// A customizer passes the values its visitor chooses as strings, which are parsed with
/// ``init(parameterString:)``.
///
/// Cadova provides conformances for `Int`, `Double`, `Bool`, `String`, `Angle` and ``Color``. String-backed
/// enums get a conformance for free by declaring it. Make the enum `CaseIterable` too, and a
/// customizer can offer its cases as a list to pick from:
///
/// ```swift
/// enum Style: String, CaseIterable, ParameterValue {
///     case plain, fancy
/// }
/// ```
///
public protocol ParameterValue: Sendable {
    /// Creates a value by parsing a string representation, as a customizer provides it.
    ///
    /// - Parameter parameterString: The string to parse.
    /// - Returns: The parsed value, or `nil` if the string is not a valid representation.
    init?(parameterString: String)

    /// A string representation that ``init(parameterString:)`` parses back into this value.
    var parameterString: String { get }

    /// The kind of value, which tells a customizer what kind of control to offer for it.
    static var parameterKind: ParameterKind { get }
}

/// The kind of value a customizer parameter holds, used to describe it to a customizer.
public enum ParameterKind: Sendable, Hashable {
    /// A whole number.
    case integer
    /// A decimal number.
    case number
    /// An angle, written in degrees.
    case angle
    /// A color, written in hexadecimal.
    case color
    /// A true or false value.
    case boolean
    /// Free text.
    case text
    /// One of a fixed set of values, given as the strings that identify them.
    case choice ([String])
}

public extension ParameterValue {
    var parameterString: String { String(describing: self) }
    static var parameterKind: ParameterKind { .text }
}

/// A parameter value that's a plain number, which a customizer can show with a unit.
///
/// `Int` and `Double` conform. Give a parameter of either type a unit with `unit:`, and a customizer
/// shows it after the number:
///
/// ```swift
/// @Parameter("Height", in: 10...50, step: 0.5, unit: "mm")
/// var height = 20.0
/// ```
///
public protocol NumericParameterValue: ParameterValue, Comparable {}

extension Int: NumericParameterValue {
    public init?(parameterString: String) {
        self.init(parameterString)
    }

    public static var parameterKind: ParameterKind { .integer }
}

extension Double: NumericParameterValue {
    public init?(parameterString: String) {
        self.init(parameterString)
    }

    public static var parameterKind: ParameterKind { .number }
}

extension String: ParameterValue {
    public init?(parameterString: String) {
        self.init(parameterString)
    }
}

extension Bool: ParameterValue {
    public init?(parameterString: String) {
        switch parameterString.lowercased() {
        case "true", "yes", "1": self = true
        case "false", "no", "0": self = false
        default: return nil
        }
    }

    public static var parameterKind: ParameterKind { .boolean }
}

extension Angle: ParameterValue {
    /// Parses an angle from a string. A plain number is interpreted as degrees; the suffixes
    /// `°`, `deg` and `rad` are also accepted (e.g. `"45"`, `"45°"`, `"45deg"`, `"0.79rad"`).
    public init?(parameterString: String) {
        let string = parameterString.trimmingCharacters(in: .whitespaces)
        for (suffix, isRadians) in [("rad", true), ("deg", false), ("°", false), ("", false)] {
            if string.hasSuffix(suffix), let value = Double(string.dropLast(suffix.count)) {
                self = isRadians ? Angle(radians: value) : Angle(degrees: value)
                return
            }
        }
        return nil
    }

    public var parameterString: String { String(degrees) }
    public static var parameterKind: ParameterKind { .angle }
}

extension Color: ParameterValue {
    /// Parses a color from hexadecimal, as a customizer writes it: `"#rrggbb"`, or `"#rrggbbaa"` with
    /// an alpha component. The `#` is optional.
    public init?(parameterString: String) {
        let digits = parameterString.trimmingCharacters(in: .whitespaces).drop { $0 == "#" }
        guard digits.count == 6 || digits.count == 8, digits.allSatisfy(\.isHexDigit) else { return nil }
        self.init(hex: String(digits))
    }

    /// The color in hexadecimal, `"#rrggbb"`, with an alpha component only if it isn't opaque.
    public var parameterString: String {
        let components = alpha < 1 ? [red, green, blue, alpha] : [red, green, blue]
        return "#" + components.map { component in
            let hex = String(Int((component * 255).rounded()), radix: 16)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }

    public static var parameterKind: ParameterKind { .color }
}

public extension ParameterValue where Self: RawRepresentable, RawValue == String {
    init?(parameterString: String) {
        self.init(rawValue: parameterString)
    }

    var parameterString: String { rawValue }
}

public extension ParameterValue where Self: RawRepresentable & CaseIterable, RawValue == String {
    static var parameterKind: ParameterKind { .choice(allCases.map(\.rawValue)) }
}
