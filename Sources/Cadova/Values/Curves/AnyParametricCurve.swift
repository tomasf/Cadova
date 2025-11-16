import Foundation

internal struct OpaqueParametricCurve<V: Vector>: Sendable {
    let curve: any ParametricCurve<V>

    init<C: ParametricCurve>(_ base: C) where C.V == V {
        self.curve = base
    }
}

extension OpaqueParametricCurve: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.curve)
    }

    static func == (lhs: OpaqueParametricCurve<V>, rhs: OpaqueParametricCurve<V>) -> Bool {
        func compare<LHS: Equatable, RHS: Equatable>(lhs: LHS, rhs: RHS) -> Bool {
            if let rhsAsLHS = rhs as? LHS { return lhs == rhsAsLHS }
            if let lhsAsRHS = lhs as? RHS { return lhsAsRHS == rhs }
            return false
        }
        return compare(lhs: lhs.curve, rhs: rhs.curve)
    }
}

extension OpaqueParametricCurve: Codable {
    private enum CodingKeys: CodingKey { case type, value }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let mangledType = _mangledTypeName(type(of: self.curve))
        try container.encode(mangledType, forKey: .type)
        try container.encode(self.curve, forKey: .value)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .type)

        guard let decodedType = _typeByName(typeName) as? any Decodable.Type else {
            fatalError("Failed to interpret mangled type \(typeName)")
        }
        let decodedValue = try container.decode(decodedType, forKey: .value)
        self.curve = decodedValue as! any ParametricCurve<V>
    }
}
