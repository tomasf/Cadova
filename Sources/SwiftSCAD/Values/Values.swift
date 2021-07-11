import Foundation

public protocol SCADFormattable {
	func scadString(environment: Environment) -> String
}

public protocol SCADValue: SCADFormattable {
	var scadString: String { get }
}

public extension SCADValue {
	func scadString(environment: Environment) -> String {
		scadString
	}
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
			self.replacingOccurrences(of: "\\", with: "\\\\") +
			self.replacingOccurrences(of: "\"", with: "\\\"") +
		"\""
	}
}

extension Array: SCADFormattable where Element: SCADValue {
	public func scadString(environment: Environment) -> String {
		scadString
	}
}

extension Array: SCADValue where Element: SCADValue {
	public var scadString: String {
		"[" + map(\.scadString).joined(separator: ", ")  + "]"
	}
}


// A OpenSCAD call to a function or module

struct SCADCall: SCADFormattable {
	let name: String
	let params: [String: SCADValue?]
	let body: SCADFormattable?

	init(name: String, params: [String: SCADValue?] = [:], body: SCADFormattable? = nil) {
		self.name = name
		self.params = params
		self.body = body
	}

	func scadString(environment: Environment) -> String {
		let paramText = params
			.compactMapValues { $0 }
			.sorted(by: { a, b in a.key < b.key })
			.map { key, value in "\(key)=\(value.scadString)"}.joined(separator: ", ")

		let bodyString: String
		if let body = body {
			bodyString = " " + body.scadString(environment: environment)
		} else {
			bodyString = ";"
		}

		return "\(name)(\(paramText))\(bodyString)"
	}
}

struct GeometrySequence: Geometry {
	let children: [Geometry]

	func scadString(environment: Environment) -> String {
		"{ " + children.map { $0.scadString(environment: environment) }.joined(separator: " ") + " }"
	}
}
