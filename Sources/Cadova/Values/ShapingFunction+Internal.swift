import Foundation

extension ShapingFunction {
    fileprivate enum Kind: String, Codable {
        case linear
        case exponential
        case easeIn
        case easeOut
        case easeInOut
        case easeInOutCubic
        case smoothstep
        case smootherstep
        case bezier
        case custom
    }

    public func hash(into hasher: inout Hasher) {
        switch curve {
        case .linear:
            hasher.combine(Kind.linear)
        case .exponential(let exponent):
            hasher.combine(Kind.exponential)
            hasher.combine(exponent)
        case .easeIn:
            hasher.combine(Kind.easeIn)
        case .easeOut:
            hasher.combine(Kind.easeOut)
        case .easeInOut:
            hasher.combine(Kind.easeInOut)
        case .easeInOutCubic:
            hasher.combine(Kind.easeInOutCubic)
        case .smoothstep:
            hasher.combine(Kind.smoothstep)
        case .smootherstep:
            hasher.combine(Kind.smootherstep)
        case .bezier (let curve):
            hasher.combine(Kind.bezier)
            hasher.combine(curve)
        case .custom (let cacheKey, _):
            hasher.combine(Kind.custom)
            hasher.combine(cacheKey)
        }
    }

    public static func == (lhs: ShapingFunction, rhs: ShapingFunction) -> Bool {
        switch (lhs.curve, rhs.curve) {
        case (.linear, .linear):
            return true

        case (.exponential(let a), .exponential(let b)):
            return a == b

        case (.easeIn, .easeIn),
            (.easeOut, .easeOut),
            (.easeInOut, .easeInOut),
            (.easeInOutCubic, .easeInOutCubic),
            (.smoothstep, .smoothstep),
            (.smootherstep, .smootherstep):
            return true

        case (.custom(let aKey, _), .custom(let bKey, _)):
            return aKey == bKey

        case (.bezier(let ac), .bezier(let bc)):
            return ac == bc

        case (.linear, _), (.easeIn, _), (.easeOut, _), (.easeInOut, _), (.easeInOutCubic, _),
            (.smoothstep, _), (.smootherstep, _), (.exponential, _), (.custom, _), (.bezier, _):
            return false
        }
    }
}

extension ShapingFunction.Curve: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case exponent
        case cacheKey
        case curve
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(ShapingFunction.Kind.self, forKey: .kind) {
        case .linear:
            self = .linear
        case .exponential:
            let exponent = try container.decode(Double.self, forKey: .exponent)
            self = .exponential(exponent: exponent)
        case .easeIn:
            self = .easeIn
        case .easeOut:
            self = .easeOut
        case .easeInOut:
            self = .easeInOut
        case .easeInOutCubic:
            self = .easeInOutCubic
        case .smoothstep:
            self = .smoothstep
        case .smootherstep:
            self = .smootherstep
        case .custom:
            let cacheKey = try container.decode(LabeledCacheKey.self, forKey: .cacheKey)
            self = .custom(cacheKey: cacheKey, function: { _ in preconditionFailure("Decoded custom curve cannot be evaluated") })
        case .bezier:
            let curve = try container.decode(BezierCurve<Vector2D>.self, forKey: .curve)
            self = .bezier(curve)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .linear:
            try container.encode(ShapingFunction.Kind.linear, forKey: .kind)
        case .exponential(let exponent):
            try container.encode(ShapingFunction.Kind.exponential, forKey: .kind)
            try container.encode(exponent, forKey: .exponent)
        case .easeIn:
            try container.encode(ShapingFunction.Kind.easeIn, forKey: .kind)
        case .easeOut:
            try container.encode(ShapingFunction.Kind.easeOut, forKey: .kind)
        case .easeInOut:
            try container.encode(ShapingFunction.Kind.easeInOut, forKey: .kind)
        case .easeInOutCubic:
            try container.encode(ShapingFunction.Kind.easeInOutCubic, forKey: .kind)
        case .smoothstep:
            try container.encode(ShapingFunction.Kind.smoothstep, forKey: .kind)
        case .smootherstep:
            try container.encode(ShapingFunction.Kind.smootherstep, forKey: .kind)
        case .custom (let cacheKey, _):
            try container.encode(ShapingFunction.Kind.custom, forKey: .kind)
            try container.encode(cacheKey, forKey: .cacheKey)
        case .bezier (let curve):
            try container.encode(ShapingFunction.Kind.bezier, forKey: .kind)
            try container.encode(curve, forKey: .curve)
        }
    }
}
