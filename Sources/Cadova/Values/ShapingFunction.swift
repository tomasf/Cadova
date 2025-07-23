import Foundation

/// A shaping function maps a value in the range 0...1 to a new value in the same range, commonly used for easing and
/// interpolation.
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
        case .easeInOutCubic: { $0 < 0.5 ? 4 * $0 * $0 * $0 : 0.5 * (2 * $0 - 2) * (2 * $0 - 2) * (2 * $0 - 2) + 1 }
        case .smoothstep: { $0 * $0 * (3 - 2 * $0) }
        case .smootherstep: { $0 * $0 * $0 * ($0 * (6 * $0 - 15) + 10) }
        case .circularEaseIn: { 1 - sqrt(1 - $0 * $0) }
        case .circularEaseOut: { sqrt(1 - (1 - $0) * (1 - $0)) }
        case .bezier (let curve): { curve.point(at: curve.t(for: $0, in: .x) ?? $0).y }
        case .custom (_, let function): function
        }
    }
}

internal extension ShapingFunction {
    enum Curve {
        case linear
        case exponential (exponent: Double)
        case easeIn
        case easeOut
        case easeInOut
        case easeInOutCubic
        case smoothstep
        case smootherstep
        case circularEaseIn
        case circularEaseOut
        case bezier (BezierCurve<Vector2D>)
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
        ShapingFunction(curve: .custom(cacheKey: LabeledCacheKey(operationName: name, parameters: parameters), function: function))
    }
}
