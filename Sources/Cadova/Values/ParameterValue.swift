import Foundation

/// A type that can be used as a customizer parameter value.
///
/// Cadova provides conformances for `Int`, `Double`, `Bool`, `String`, `Angle` and ``Color``. For
/// an enum whose cases a customizer offers to pick from, use ``ParameterChoice``.
///
public protocol ParameterValue: Sendable {
    /// Creates a value by parsing a string representation, as a customizer provides it.
    ///
    /// - Parameter parameterString: The string to parse.
    /// - Returns: The parsed value, or `nil` if the string is not a valid representation.
    @_spi(ParameterInternals) init?(parameterString: String)

    /// A string representation that ``init(parameterString:)`` parses back into this value.
    @_spi(ParameterInternals) var parameterString: String { get }
}

/// The kind of value a customizer parameter holds, which tells a customizer what kind of control to
/// offer for it.
internal enum ParameterKind: Sendable, Hashable {
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
    /// One of a fixed set of options.
    case choice ([Option])

    /// One of the values a choice offers: the string that identifies it, as `parameterString` writes
    /// it, and what a customizer calls it
    struct Option: Sendable, Hashable {
        let value: String
        let label: String
    }

    /// The kind of a type of value. Types that Cadova knows of have their own, and any other is text.
    init<Value: ParameterValue>(_ type: Value.Type) {
        if let choice = type as? any ParameterChoice.Type {
            self = choice.parameterKind
        } else {
            self = (type as? any KnownParameterValue.Type)?.parameterKind ?? .text
        }
    }
}

/// A type of parameter value with its own kind of control
internal protocol KnownParameterValue: ParameterValue {
    static var parameterKind: ParameterKind { get }
}

public extension ParameterValue {
    @_spi(ParameterInternals) var parameterString: String { String(describing: self) }
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
    @_spi(ParameterInternals) public init?(parameterString: String) {
        self.init(parameterString)
    }
}

extension Int: KnownParameterValue {
    static var parameterKind: ParameterKind { .integer }
}

extension Double: NumericParameterValue {
    @_spi(ParameterInternals) public init?(parameterString: String) {
        self.init(parameterString)
    }
}

extension Double: KnownParameterValue {
    static var parameterKind: ParameterKind { .number }
}

extension String: ParameterValue {
    @_spi(ParameterInternals) public init?(parameterString: String) {
        self.init(parameterString)
    }
}

extension Bool: ParameterValue {
    @_spi(ParameterInternals) public init?(parameterString: String) {
        switch parameterString.lowercased() {
        case "true", "yes", "1": self = true
        case "false", "no", "0": self = false
        default: return nil
        }
    }
}

extension Bool: KnownParameterValue {
    static var parameterKind: ParameterKind { .boolean }
}

extension Angle: ParameterValue {
    /// Parses an angle from a string. A plain number is interpreted as degrees; the suffixes
    /// `°`, `deg` and `rad` are also accepted (e.g. `"45"`, `"45°"`, `"45deg"`, `"0.79rad"`).
    @_spi(ParameterInternals) public init?(parameterString: String) {
        let string = parameterString.trimmingCharacters(in: .whitespaces)
        for (suffix, isRadians) in [("rad", true), ("deg", false), ("°", false), ("", false)] {
            if string.hasSuffix(suffix), let value = Double(string.dropLast(suffix.count)) {
                self = isRadians ? Angle(radians: value) : Angle(degrees: value)
                return
            }
        }
        return nil
    }

    @_spi(ParameterInternals) public var parameterString: String { String(degrees) }
}

extension Angle: KnownParameterValue {
    static var parameterKind: ParameterKind { .angle }
}

extension Color: ParameterValue {
    /// Parses a color from hexadecimal, as a customizer writes it: `"#rrggbb"`, or `"#rrggbbaa"` with
    /// an alpha component. The `#` is optional.
    @_spi(ParameterInternals) public init?(parameterString: String) {
        let digits = parameterString.trimmingCharacters(in: .whitespaces).drop { $0 == "#" }
        guard digits.count == 6 || digits.count == 8, digits.allSatisfy(\.isHexDigit) else { return nil }
        self.init(hex: String(digits))
    }

    /// The color in hexadecimal, `"#rrggbb"`, with an alpha component only if it isn't opaque.
    @_spi(ParameterInternals) public var parameterString: String {
        let components = alpha < 1 ? [red, green, blue, alpha] : [red, green, blue]
        return "#" + components.map { component in
            let hex = String(Int((component * 255).rounded()), radix: 16)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }
}

extension Color: KnownParameterValue {
    static var parameterKind: ParameterKind { .color }
}

/// An enum whose cases a customizer offers to pick from, as buttons or a menu.
///
/// Give the enum a raw type, such as `String` or `Int`, and declare the conformance. Each case's
/// raw value identifies it, and a customizer names it after the case, so `extraFine` reads
/// "Extra fine":
///
/// ```swift
/// enum Quality: String, ParameterChoice {
///     case draft, standard, extraFine
/// }
/// ```
///
/// To name a case differently, implement ``displayName``:
///
/// ```swift
/// enum Material: String, ParameterChoice {
///     case pla, petg
///
///     var displayName: String {
///         switch self {
///         case .pla: "PLA"
///         case .petg: "PETG"
///         }
///     }
/// }
/// ```
///
public protocol ParameterChoice: ParameterValue, CaseIterable, RawRepresentable
where RawValue: LosslessStringConvertible {
    /// What a customizer calls this case. By default, the case's name, written as words.
    var displayName: String { get }
}

public extension ParameterChoice {
    init?(parameterString: String) {
        guard let rawValue = RawValue(parameterString) else { return nil }
        self.init(rawValue: rawValue)
    }

    var parameterString: String { String(rawValue) }

    var displayName: String {
        Self.words(in: String(describing: self))
    }

    /// A name written as words, with only the first capitalized: `extraFine` and `extra_fine` read
    /// "Extra fine". Words in capitals, such as `PLA`, keep them.
    private static func words(in name: String) -> String {
        var words: [String] = []
        var word = ""
        var previous: Character?
        for character in name {
            if character == "_" || character == "-" || character == " " {
                if !word.isEmpty { words.append(word) }
                word = ""
            } else if character.isUppercase, let previous, previous.isLowercase || previous.isNumber {
                words.append(word)
                word = String(character)
            } else {
                word.append(character)
            }
            previous = character
        }
        if !word.isEmpty { words.append(word) }

        let written = words.enumerated().map { index, word in
            if word.count > 1, word.allSatisfy({ !$0.isLetter || $0.isUppercase }) { return word }
            let lowercased = word.lowercased()
            return index == 0 ? lowercased.prefix(1).uppercased() + lowercased.dropFirst() : lowercased
        }
        return written.joined(separator: " ")
    }
}

internal extension ParameterChoice {
    static var parameterKind: ParameterKind {
        .choice(allCases.map { .init(value: $0.parameterString, label: $0.displayName) })
    }
}
