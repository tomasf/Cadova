import Foundation

public struct Offset: CoreGeometry2D {
    let amount: Double
    let style: Style
    let body: Geometry2D

    func call(in environment: Environment) -> SCADCall {
        let params: [String: SCADValue]

        switch style {
        case .round:
            params = ["r": amount]
        case .miter:
            params = ["delta": amount]
        case .bevel:
            params = ["delta": amount, "chamfer": true]
        }

        return SCADCall(name: "offset", params: params, body: body)
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
    func offset(amount: Double, style: Offset.Style) -> Geometry2D {
        Offset(amount: amount, style: style, body: self)
    }

    func rounded(amount: Double, side: Offset.Side = .both) -> Geometry2D {
        var body: Geometry2D = self
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
