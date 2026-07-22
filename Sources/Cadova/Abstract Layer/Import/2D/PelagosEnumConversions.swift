import Foundation
internal import Pelagos

internal extension FillRule {
    init(from pelagosRule: Pelagos.FillRule) {
        switch pelagosRule {
        case .nonzero:
            self = .nonZero
        case .evenodd:
            self = .evenOdd
        }
    }
}

internal extension LineJoinStyle {
    init(from pelagosJoin: Pelagos.LineJoin) {
        switch pelagosJoin {
        case .miter, .miterClip, .arcs:
            self = .miter
        case .round:
            self = .round
        case .bevel:
            self = .bevel
        }
    }
}

internal extension LineCapStyle {
    init(from pelagosCap: Pelagos.LineCap) {
        switch pelagosCap {
        case .butt:
            self = .butt
        case .round:
            self = .round
        case .square:
            self = .square
        }
    }
}
