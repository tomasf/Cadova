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
///     layer(z: 0) { Circle(diameter: 10) }
///     layer(z: 20, interpolation: .easeInOut) { Circle(diameter: 20) }
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
        case .exponential (let exponent): { pow(1.0 - $0, exponent) }
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

public extension ShapingFunction {
    /// A linear shaping function that returns the input unchanged, producing a constant rate of change.
    /// This function is useful when no easing or shaping is desired.
    static var linear: Self {
        ShapingFunction(curve: .linear)
    }

    /// An exponential shaping function that produces a curve which accelerates slowly at the start and rapidly near
    /// the end. The `exponent` parameter controls the steepness of the curve; higher values produce more pronounced
    /// acceleration. This function is useful for simulating easing effects where acceleration increases exponentially.
    ///
    /// - Parameter exponent: A positive value determining the curve's steepness.
    /// - Returns: A shaping function applying exponential easing.
    static func exponential(_ exponent: Double) -> Self {
        ShapingFunction(curve: .exponential(exponent: exponent))
    }

    /// A quadratic ease-in function that starts slow and accelerates towards the end.
    /// It produces a smooth curve where the rate of change increases over time, simulating natural acceleration.
    static var easeIn: Self {
        ShapingFunction(curve: .easeIn)
    }

    /// A quadratic ease-out function that starts fast and decelerates towards the end.
    /// It produces a smooth curve where the rate of change decreases over time, simulating natural deceleration.
    static var easeOut: Self {
        ShapingFunction(curve: .easeOut)
    }

    /// A quadratic ease-in-out function that accelerates in the first half and decelerates in the second half.
    /// This function creates a smooth transition with gradual acceleration and deceleration, ideal for natural motion
    /// effects.
    static var easeInOut: Self {
        ShapingFunction(curve: .easeInOut)
    }

    /// A cubic ease-in function that starts slow and accelerates towards the end.
    /// Produces a more pronounced acceleration than the quadratic ``easeIn``.
    static var easeInCubic: Self {
        ShapingFunction(curve: .easeInCubic)
    }

    /// A cubic ease-out function that starts fast and decelerates towards the end.
    /// Produces a more pronounced deceleration than the quadratic ``easeOut``.
    static var easeOutCubic: Self {
        ShapingFunction(curve: .easeOutCubic)
    }

    /// A cubic ease-in-out function that provides a stronger smoothing effect than quadratic easing.
    /// It accelerates slowly at the start, speeds up through the middle, and decelerates smoothly at the end.
    /// This function is useful for more pronounced easing effects with smoother transitions.
    static var easeInOutCubic: Self {
        ShapingFunction(curve: .easeInOutCubic)
    }

    /// A smoothstep function that provides smooth interpolation with zero first derivative at the endpoints.
    /// It starts and ends with zero velocity, producing smooth easing without abrupt changes.
    static var smoothstep: Self {
        ShapingFunction(curve: .smoothstep)
    }

    /// A smootherstep function that extends smoothstep by also having zero second derivative at the endpoints.
    /// This results in even smoother transitions with continuous acceleration and deceleration, minimizing visual
    /// artifacts.
    static var smootherstep: Self {
        ShapingFunction(curve: .smootherstep)
    }

    /// A circular ease-in shaping function.
    /// Starts slow and curves sharply near the end.
    static var circularEaseIn: Self {
        ShapingFunction(curve: .circularEaseIn)
    }

    /// A circular ease-out shaping function.
    /// Starts sharply and levels out.
    static var circularEaseOut: Self {
        ShapingFunction(curve: .circularEaseOut)
    }

    /// A sine-based shaping function using a half cosine wave.
    ///
    /// Produces smooth acceleration and deceleration with continuous derivatives at all points.
    /// This creates a natural-feeling ease-in-out effect based on trigonometric functions.
    static var sine: Self {
        ShapingFunction(curve: .sine)
    }

    /// A cubic Bézier-based shaping function mapping input from 0 to 1 onto the curve defined by two control points.
    ///
    /// The resulting function is suitable for easing, interpolation, and other shaping purposes.
    ///
    /// - Important: The Bézier curve must be monotonic in X over the interval [0, 1] to behave as a proper function.
    ///   If the curve is not monotonic, results may be unpredictable.
    /// - Parameters:
    ///   - controlPoint1: The first control point.
    ///   - controlPoint2: The second control point.
    /// - Returns: A shaping function using a cubic Bézier interpolation from (0,0) to (1,1).
    ///
    /// Output values are always capped (clamped) to the range 0...1.
    static func bezier(_ controlPoint1: Vector2D, _ controlPoint2: Vector2D) -> Self {
        ShapingFunction(curve: .bezier(BezierCurve(controlPoints: [[0,0], controlPoint1, controlPoint2, [1,1]])))
    }

    /// A custom shaping function.
    /// The function is cached based on the supplied `name` and `parameters`. If the same
    /// combination of input geometry and cache parameters has been previously evaluated, the cached result is reused
    /// to avoid redundant computation. Ensure that these parameters are stable and deterministic; the same set of
    /// name + parameters should always result in an identical function.
    ///
    /// - Parameters:
    ///   - name: A name to identify the function.
    ///   - parameters: Parameters contributing to the cache key.
    ///   - function: A function mapping input `t` to output `t'`.
    /// - Returns: A shaping function with custom logic.
    ///
    static func custom(
        name: String,
        parameters: any Hashable & Sendable & Codable...,
        function: @escaping @Sendable (Double) -> Double
    ) -> Self {
        ShapingFunction(curve: .custom(
            cacheKey: LabeledCacheKey(operationName: name, parameters: parameters),
            function: function
        ))
    }
}

public extension ShapingFunction {
    /// Constructs a new shaping function that blends this function with another.
    ///
    /// The resulting function applies a weighted mix between `self` and `other`.
    /// When `weight` is 0.0, the result is identical to `self`. When `weight` is 1.0, the
    /// result is identical to `other`. Intermediate weights produce a linear interpolation
    /// between the two functions' outputs.
    ///
    /// This is useful when you want to gradually transition between two shaping behaviors.
    ///
    /// - Parameters:
    ///   - other: The shaping function to blend with.
    ///   - weight: A value between 0.0 and 1.0 indicating how much of `other` to include.
    /// - Returns: A new shaping function representing the blend.
    /// - Precondition: `weight` must be between 0.0 and 1.0, inclusive.
    ///
    func mixed(with other: ShapingFunction, weight: Double) -> Self {
        precondition(weight >= 0 && weight <= 1)
        return ShapingFunction(curve: .mix(self, other, weight))
    }

    /// Returns an inverted version of this shaping function.
    ///
    /// The inverted function is reflected about the point (0.5, 0.5), computed as `g(t) = 1 - f(1 - t)`.
    /// This swaps the behavior at the start and end of the curve:
    /// - Ease-in becomes ease-out
    /// - Ease-out becomes ease-in
    /// - Linear and symmetric functions (like `sine`) remain unchanged
    ///
    /// ```swift
    /// let easeOut = ShapingFunction.easeIn.inverted  // Equivalent to .easeOut
    /// ```
    ///
    var inverted: Self {
        ShapingFunction(curve: .inverted(self))
    }

    /// Returns a mirrored version of this shaping function.
    ///
    /// The mirrored function is geometrically reflected across the line y = x,
    /// computed as the inverse function `g(t) = f⁻¹(t)`. This produces true visual
    /// symmetry when the original and mirrored curves are plotted together.
    ///
    /// - Ease-in (below diagonal) becomes a curve above the diagonal
    /// - Ease-out (above diagonal) becomes a curve below the diagonal
    /// - Linear remains unchanged
    ///
    /// The inverse is computed numerically using binary search, which works for
    /// any monotonic shaping function.
    ///
    /// ```swift
    /// let reflected = ShapingFunction.easeIn.mirrored  // Visually symmetric across y = x
    /// ```
    ///
    var mirrored: Self {
        ShapingFunction(curve: .mirrored(self))
    }
}
