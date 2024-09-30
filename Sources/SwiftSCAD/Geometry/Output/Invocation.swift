import Foundation

public struct Invocation: Sendable {
    public typealias Parameters = [String: (any SCADValue)?]

    private indirect enum Content {
        case empty
        case call (name: String, parameters: [String: any SCADValue], body: [Invocation])
        case prefix (String, Invocation)
    }

    private let content: Content

    private init(content: Content) {
        self.content = content
    }

    internal init(name: String, parameters: Parameters = [:], body: [Invocation?]) {
        self.init(content: .call(
            name: name,
            parameters: parameters.compactMapValues { $0 },
            body: body.compactMap { $0 }
        ))
    }

    internal init(prefix: String, body: Invocation) {
        self.init(content: .prefix(prefix, body))
    }

    internal static let empty = Invocation(content: .empty)

    /*
    internal func adding(parameter key: String, value: any SCADValue) -> Invocation {
        .init(name: name, parameters: parameters.merging([key: value]) { $1 }, body: body)
    }
*/
    internal var scadCode: String {
        switch content {
        case .empty: return ";"
        case .prefix(let string, let invocation): return string + invocation.scadCode
        case .call(let name, let parameters, let body):
            let paramText = parameters
                .sorted { $0.key < $1.key }
                .map { "\($0)=\($1.scadString)"}
                .joined(separator: ", ")
            let head = "\(name)(\(paramText))"

            if body.count > 1 {
                return "\(head) { \(body.map(\.scadCode).joined(separator: " ")) }"
            } else if body.count == 1 {
                return "\(head) \(body[0].scadCode)"
            } else {
                return "\(head);"
            }
        }
    }
}
