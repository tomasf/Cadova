import Foundation

public protocol SCADFormattable {
	func scadString(in environment: Environment) -> String
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


// A OpenSCAD call to a function or module
// name(params) body

struct SCADCall: SCADFormattable {
	let name: String
	let params: [String: SCADValue?]
	let body: SCADFormattable?

	init(name: String, params: [String: SCADValue?] = [:], body: SCADFormattable? = nil) {
		self.name = name
		self.params = params
		self.body = body
	}

	func scadString(in environment: Environment) -> String {
		let paramText = params
			.compactMapValues { $0 }
			.sorted(by: { a, b in a.key < b.key })
			.map { key, value in "\(key)=\(value.scadString)"}.joined(separator: ", ")

		let bodyString: String
		if let body = body {
			bodyString = " " + body.scadString(in: environment)
		} else {
			bodyString = ";"
		}

		return "\(name)(\(paramText))\(bodyString)"
	}
}

struct GeometrySequence: Geometry {
	let children: [Geometry]

	func scadString(in environment: Environment) -> String {
		"{ " + children.map { $0.scadString(in: environment) }.joined(separator: " ") + " }"
	}
}
