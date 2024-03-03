import Foundation

// A OpenSCAD call to a function or module
// name(params) body

struct SCADCall: SCADFormattable {
    let name: String
    let params: [String: (any SCADValue)?]
    let body: (any SCADFormattable)?
    let bodyEnvironment: Environment?

    init(name: String, params: [String: (any SCADValue)?] = [:], body: (any SCADFormattable)? = nil, bodyEnvironment: Environment? = nil) {
        self.name = name
        self.params = params
        self.body = body
        self.bodyEnvironment = bodyEnvironment
    }

    func scadString(in environment: Environment) -> String {
        let paramText = params
            .compactMapValues { $0 }
            .sorted { $0.key < $1.key }
            .map { key, value in "\(key)=\(value.scadString)"}
            .joined(separator: ", ")

        let bodyString = body.map { " " + $0.scadString(in: bodyEnvironment ?? environment) } ?? ";"
        return "\(name)(\(paramText))\(bodyString)"
    }
}
