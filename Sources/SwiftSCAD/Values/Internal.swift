import Foundation

public protocol SCADFormattable {
    func scadString(in environment: Environment) -> String
}

struct GeometrySequence: Geometry {
    let children: [any Geometry]

    func scadString(in environment: Environment) -> String {
        "{ " + children.map { $0.scadString(in: environment) }.joined(separator: " ") + " }"
    }
}

protocol SCADValue: SCADFormattable {
    var scadString: String { get }
}

extension SCADValue {
    public func scadString(in environment: Environment) -> String {
        scadString
    }
}

extension Double: SCADValue {
    var scadString: String {
        String(format: "%.06f", self)
    }
}

extension Int: SCADValue {
    public var scadString: String {
        String(self)
    }
}

extension Bool: SCADValue {
    public var scadString: String {
        String(self)
    }
}

extension String: SCADValue {
    public var scadString: String {
        "\"" +
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\"", with: "\\\"") +
        "\""
    }
}

extension Array: SCADFormattable where Element: SCADFormattable {
    public func scadString(in environment: Environment) -> String {
        "[" + map { $0.scadString(in: environment) }.joined(separator: ", ")  + "]"
    }
}

extension Array: SCADValue where Element: SCADValue {
    var scadString: String {
        "[" + map(\.scadString).joined(separator: ", ")  + "]"
    }
}
