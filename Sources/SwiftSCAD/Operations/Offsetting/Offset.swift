import Foundation

public struct Offset: WrapperGeometry2D {
    let body: any Geometry2D
    let amount: Double
    let style: Style

    public var invocation: Invocation? {
        let params: [String: any SCADValue]

        switch style {
        case .round:
            params = ["r": amount]
        case .miter:
            params = ["delta": amount]
        case .bevel:
            params = ["delta": amount, "chamfer": true]
        }

        return .init(name: "offset", parameters: params)
    }

    public enum Style {
        case round
        case miter
        case bevel
    }

    public enum Side {
        case outside
        case inside
        case both
    }
}

public extension Geometry2D {
    func offset(amount: Double, style: Offset.Style) -> any Geometry2D {
        Offset(body: self, amount: amount, style: style)
    }

    func rounded(amount: Double, side: Offset.Side = .both) -> any Geometry2D {
        var body: any Geometry2D = self
        if side != .inside {
            body = body
                .offset(amount: -amount, style: .miter)
                .offset(amount: amount, style: .round)
        }
        if side != .outside {
            body = body
                .offset(amount: amount, style: .miter)
                .offset(amount: -amount, style: .round)
        }
        return body
    }
}
