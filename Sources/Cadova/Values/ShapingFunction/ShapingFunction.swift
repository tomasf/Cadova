import Foundation

/// A function that maps values from 0...1 to 0...1, used for easing and interpolation.
///
/// Shaping functions control how values transition between start and end points. They are used
/// throughout Cadova for operations like lofting, sweeping, and other interpolated transformations.
///
/// Use one of the built-in functions like ``linear``, ``easeIn``, ``easeOut``, or ``smoothstep``,
/// or create a custom function with ``bezier(_:_:)`` or ``custom(name:parameters:function:)``.
///
/// ```swift
/// // Use a shaping function to control loft interpolation
/// Loft {
///     Section(at: 0) { Circle(diameter: 10) }
///     Section(at: 20, interpolation: .easeInOut) { Circle(diameter: 20) }
/// }
/// ```
///
/// You can call shaping functions directly:
/// ```swift
/// let eased = ShapingFunction.easeInOut(0.5)  // Returns ~0.5
/// ```
///
public struct ShapingFunction: Sendable, Hashable, Codable {
    internal let curve: Curve

    /// Returns a closure that evaluates this shaping function.
    ///
    /// The returned closure maps a value in the range `0.0...1.0` to a shaped output, also in `0.0...1.0`.
    /// This closure can be used for interpolation, easing, animation, or any other context where a non-linear mapping
    /// is desired.
    public var function: @Sendable (Double) -> Double {
        switch curve {
        case .linear: { $0 }
        case .exponential (let exponent): { pow($0, exponent) }
        case .easeIn: { $0 * $0 }
        case .easeOut: { 1 - (1 - $0) * (1 - $0)  }
        case .easeInOut: { $0 < 0.5 ? 2 * $0 * $0 : -2 * $0 * $0 + 4 * $0 - 1 }
        case .easeInCubic: { $0 * $0 * $0 }
        case .easeOutCubic: { let t = 1 - $0; return 1 - t * t * t }
        case .easeInOutCubic: { $0 < 0.5 ? 4 * $0 * $0 * $0 : 0.5 * (2 * $0 - 2) * (2 * $0 - 2) * (2 * $0 - 2) + 1 }
        case .smoothstep: { $0 * $0 * (3 - 2 * $0) }
        case .smootherstep: { $0 * $0 * $0 * ($0 * (6 * $0 - 15) + 10) }
        case .circularEaseIn: { 1 - sqrt(1 - $0 * $0) }
        case .circularEaseOut: { sqrt(1 - (1 - $0) * (1 - $0)) }
        case .sine: { (1 - cos($0 * .pi)) / 2 }
        case .bezier (let curve): { curve.point(at: curve.t(for: $0, in: .x) ?? $0).y }
        case .mix (let a, let b, let weight): { (1 - weight) * a.function($0) + weight * b.function($0) }
        case .inverted (let base): { t in 1 - base.function(1 - t) }
        case .mirrored (let base): { t in
            // Find t' such that base(t') = t using binary search
            var low = 0.0
            var high = 1.0
            let f = base.function
            for _ in 0..<50 { // Enough iterations for Double precision
                let mid = (low + high) / 2
                if f(mid) < t {
                    low = mid
                } else {
                    high = mid
                }
            }
            return (low + high) / 2
        }
        case .custom (_, let function): function
        }
    }

    /// Evaluates the shaping function at the given input value.
    ///
    /// - Parameter input: A value typically in the range 0...1.
    /// - Returns: The shaped output value.
    ///
    public func callAsFunction(_ input: Double) -> Double {
        function(input)
    }
}

internal extension ShapingFunction {
    indirect enum Curve {
        case linear
        case exponential (exponent: Double)
        case easeIn
        case easeOut
        case easeInOut
        case easeInCubic
        case easeOutCubic
        case easeInOutCubic
        case smoothstep
        case smootherstep
        case circularEaseIn
        case circularEaseOut
        case sine
        case bezier (BezierCurve<Vector2D>)
        case mix (ShapingFunction, ShapingFunction, Double)
        case inverted (ShapingFunction)
        case mirrored (ShapingFunction)
        case custom (cacheKey: LabeledCacheKey, function: @Sendable (Double) -> Double)
    }
}
