import Foundation

public struct CodeFragment: Sendable {
    public typealias Parameters = [String: (any SCADValue)?]

    private indirect enum Fragment {
        case empty
        case call (module: String, parameters: [String: any SCADValue], body: [CodeFragment])
        case prefix (String, CodeFragment)
    }

    private let fragment: Fragment

    private init(_ content: Fragment) {
        self.fragment = content
    }

    internal init(module: String, parameters: Parameters = [:], body: [CodeFragment?]) {
        self.init(.call(
            module: module,
            parameters: parameters.compactMapValues { $0 },
            body: body.compactMap { $0 }
        ))
    }

    internal init(prefix: String, body: CodeFragment) {
        self.init(.prefix(prefix, body))
    }

    internal static let empty = CodeFragment(.empty)

    internal var scadCode: String {
        switch fragment {
        case .empty:
            return ";"

        case .prefix(let string, let fragment):
            return string + fragment.scadCode

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
