import Foundation

public struct Invocation {
    internal typealias Parameters = [String: (any SCADValue)?]

    private let name: String
    private let parameters: [String: any SCADValue]

    internal init(name: String, parameters: Parameters = [:]) {
        self.name = name
        self.parameters = parameters.compactMapValues { $0 }
    }

    internal func adding(parameter key: String, value: any SCADValue) -> Invocation {
        .init(name: name, parameters: parameters.merging([key: value]) { $1 })
    }

    internal func scadCode(body: [String] = []) -> String {
        let paramText = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0)=\($1.scadString)"}
            .joined(separator: ", ")
        let head = "\(name)(\(paramText))"

        if body.count > 1 {
            return "\(head) { \(body.joined(separator: " ")) }"
        } else if body.count == 1 {
            return "\(head) \(body[0])"
        } else {
            return "\(head);"
        }
    }
}
