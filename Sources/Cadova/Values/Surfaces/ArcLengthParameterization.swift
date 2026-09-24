import Foundation

/// A curve evaluated by the fraction of its length rather than by its own parameter.
///
/// Surfaces built from several curves match points on them by position along each curve. A curve's own
/// parameter is a poor measure of that: a path with a short segment and a long one spends half its parameter
/// range on each, so two paths with different segment layouts would pair up points that sit at very different
/// places along them. Measuring by length makes "halfway along" mean the same thing on every curve.
///
internal struct ArcLengthParameterization<Curve: ParametricCurve<Vector3D>>: Sendable, Hashable, Codable {
    let curve: Curve
    private let table: [Entry]

    private struct Entry {
        let distance: Double
        let parameter: Double
    }

    // Parameter samples used to measure the curve. The lookup interpolates between them, so this bounds how far
    // a point can drift from its exact arc-length position, not whether it lies on the curve: every returned
    // point is evaluated on the curve itself.
    private static var sampleCount: Int { 1024 }

    init(_ curve: Curve) {
        self.curve = curve

        let domain = curve.domain
        let span = domain.upperBound - domain.lowerBound
        var table: [Entry] = []
        table.reserveCapacity(Self.sampleCount + 1)
        var distance = 0.0
        var previous: Vector3D? = nil
        for i in 0...Self.sampleCount {
            let parameter = domain.lowerBound + span * Double(i) / Double(Self.sampleCount)
            let point = curve.point(at: parameter)
            if let previous {
                distance += point.distance(to: previous)
            }
            table.append(Entry(distance: distance, parameter: parameter))
            previous = point
        }
        self.table = table
    }

    var length: Double { table.last!.distance }

    /// Returns the point the given fraction of the way along the curve, measured by length.
    func point(atFraction fraction: Double) -> Vector3D {
        let fraction = fraction.clamped(to: 0...1)
        guard length > 0 else {
            // A curve without length has nowhere to measure along; fall back to its own parameter.
            let domain = curve.domain
            return curve.point(at: domain.lowerBound + (domain.upperBound - domain.lowerBound) * fraction)
        }

        let (index, localFraction) = table.binarySearch(target: fraction * length, key: \.distance)
        guard index + 1 < table.count else { return curve.point(at: table[index].parameter) }
        let lower = table[index].parameter, upper = table[index + 1].parameter
        return curve.point(at: lower + (upper - lower) * localFraction)
    }

    var startPoint: Vector3D { curve.point(at: curve.domain.lowerBound) }
    var endPoint: Vector3D { curve.point(at: curve.domain.upperBound) }

    // The table is derived entirely from the curve, so identity and encoding are the curve's alone.

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.curve == rhs.curve
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(curve)
    }

    init(from decoder: any Decoder) throws {
        self.init(try Curve(from: decoder))
    }

    func encode(to encoder: any Encoder) throws {
        try curve.encode(to: encoder)
    }
}
