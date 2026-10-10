import Foundation

/// A type that can be used as a customizer parameter value.
///
/// A customizer passes the values its visitor chooses as strings, which are parsed with
/// ``init(parameterString:)``.
///
/// Cadova provides conformances for `Int`, `Double`, `Bool`, `String` and `Angle`. String-backed
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

extension Int: ParameterValue {
    public init?(parameterString: String) {
        self.init(parameterString)
    }

    public static var parameterKind: ParameterKind { .integer }
}

extension Double: ParameterValue {
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

public extension ParameterValue where Self: RawRepresentable, RawValue == String {
    init?(parameterString: String) {
        self.init(rawValue: parameterString)
    }

    var parameterString: String { rawValue }
}

public extension ParameterValue where Self: RawRepresentable & CaseIterable, RawValue == String {
    static var parameterKind: ParameterKind { .choice(allCases.map(\.rawValue)) }
}
