import Foundation

/// Finds a tangent direction by sampling a curve either side of `u`, widening the sampling window until
/// the difference between the samples rises above floating-point noise.
///
/// A plain central difference is fine almost everywhere and wrong exactly where it matters. It vanishes
/// identically wherever a curve is momentarily stationary — a repeated control point, a segment
/// collapsed onto a single position — and cancels to rounding noise where a curve reverses on itself.
/// `Direction` normalizes whatever it is handed, so the result there is either a zero-length "unit"
/// vector or a unit vector made entirely of rounding error. Neither is detectable downstream: the
/// frame, plane or sweep built from it is simply, silently wrong.
///
/// The fallbacks, in order: a wider central difference, then a one-sided difference (at a cusp the two
/// sides cancel exactly, but each side on its own is a real direction), then the chord across the whole
/// curve.
///
/// - Parameters:
///   - u: The parameter to evaluate the tangent at.
///   - domain: The curve's parameter domain. Samples are never taken outside it.
///   - baseStep: The initial half-width of the sampling window, in parameter units.
///   - point: The curve's point function.
/// - Returns: A unit direction, or ``Direction/undefined`` for a curve that is a single point and so
///   has no tangent at all.
///
internal func finiteDifferenceTangent<V: Vector>(
    at u: Double,
    over domain: ClosedRange<Double>,
    baseStep: Double,
    point: (Double) -> V
) -> Direction<V.D> {
    // Significance is measured relative to the coordinates themselves, so the threshold scales with the
    // model rather than assuming millimetre-sized geometry. 1e-12 sits a few thousand ulps above the
    // rounding error of the subtraction, which is comfortably below any difference that carries shape.
    func isSignificant(_ a: V, _ b: V) -> Bool {
        (b - a).magnitude > Swift.max(a.magnitude, b.magnitude, .leastNormalMagnitude) * 1e-12
    }

    let center = point(u)

    for step in [baseStep, baseStep * 100, baseStep * 10_000] {
        let before = point((u - step).clamped(to: domain))
        let after = point((u + step).clamped(to: domain))

        if isSignificant(before, after) { return Direction(after - before) }
        // Look forward first, matching the curve's own direction of travel.
        if isSignificant(center, after) { return Direction(after - center) }
        if isSignificant(before, center) { return Direction(center - before) }
    }

    let start = point(domain.lowerBound)
    let end = point(domain.upperBound)
    return isSignificant(start, end) ? Direction(end - start) : .undefined
}
