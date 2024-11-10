import Foundation

internal protocol SCADValue: Sendable {
    var scadString: String { get }
}

extension Double: SCADValue {
    public var scadString: String {
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

extension Array: SCADValue where Element: SCADValue {
    var scadString: String {
        "[" + map(\.scadString).joined(separator: ", ")  + "]"
    }
}
