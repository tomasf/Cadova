import Foundation

extension SplineCurve: Codable {
    private enum CodingKeys: String, CodingKey {
        case degree
        case knots
        case controlPoints
    }

    private struct ControlPointRecord: Codable {
        var point: V
        var weight: Double
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let degree = try container.decode(Int.self, forKey: .degree)
        let knots = try container.decode([Double].self, forKey: .knots)
        let records = try container.decode([ControlPointRecord].self, forKey: .controlPoints)
        let controlPoints = records.map { ($0.point, $0.weight) }
        self.init(degree: degree, knots: knots, controlPoints: controlPoints)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(degree, forKey: .degree)
        try container.encode(knots, forKey: .knots)
        let records = controlPoints.map { ControlPointRecord(point: $0, weight: $1) }
        try container.encode(records, forKey: .controlPoints)
    }
}

extension SplineCurve: Hashable {
    public static func == (lhs: SplineCurve<V>, rhs: SplineCurve<V>) -> Bool {
        guard lhs.degree == rhs.degree,
              lhs.knots == rhs.knots,
              lhs.controlPoints.count == rhs.controlPoints.count
        else { return false }

        for ((pa, wa), (pb, wb)) in zip(lhs.controlPoints, rhs.controlPoints) {
            guard pa == pb, wa == wb else { return false }
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(degree)
        hasher.combine(knots.count)
        hasher.combine(knots)
        for (p, w) in controlPoints {
            hasher.combine(p)
            hasher.combine(w)
        }
    }
}
