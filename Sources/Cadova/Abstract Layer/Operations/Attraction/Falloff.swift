import Foundation

public protocol Falloff: Sendable, Hashable, Codable {
    func value(normalized t: Double) -> Double
}

public struct BuiltinFalloff: Falloff {
    private let function: Function

    internal init(_ function: Function) {
        self.function = function
    }

    internal enum Function: Hashable, Codable {
        case none
        case linear
        case smoothstep
        case exponential (exponent: Double)
    }

    public func value(normalized t: Double) -> Double {
        switch function {
        case .none:
            return 1.0
        case .linear:
            return 1.0 - t
        case .smoothstep:
            return t * t * (3 - 2 * t)
        case .exponential(let exponent):
            return pow(1.0 - t, exponent)
        }
    }
}

@available(macOS 15, *)
public struct ExpressionFalloff: Falloff {
    internal let expression: Expression<Double, Double>

    public func value(normalized t: Double) -> Double {
        try! expression.evaluate(t)
    }

    public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.expression.dataRepresentation == rhs.expression.dataRepresentation
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(expression.dataRepresentation)
    }
}

@available(macOS 15, *)
internal extension Expression {
    var dataRepresentation: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try! encoder.encode(self)
    }
}


public extension Falloff where Self == BuiltinFalloff {
    /// A falloff that applies no distance-based reduction within the influence radius.
    /// All points move the same distance (up to `maxMovement`), regardless of how close or far they are from the target.
    static var none: Self { Self(.none) }

    /// A linearly decreasing falloff that reaches 0 at the normalized distance 1.0.
    ///
    /// Influence starts at full strength when the point is at the target (distance 0)
    /// and decreases linearly until `influenceRadius`, beyond which it becomes zero.
    /// The falloff value is multiplied by `maxMovement` to determine how far each point is moved.
    static var linear: Self { Self(.linear) }

    /// A smooth, S-shaped falloff curve using a cubic smoothstep.
    ///
    /// Influence starts at full strength at the target (distance 0),
    /// decreases smoothly, and reaches 0 at `influenceRadius`.
    /// Designed to create gentle transitions with no harsh edges.
    /// The falloff value is multiplied by `maxMovement` to determine how far each point is moved.
    static var smoothstep: Self { Self(.smoothstep) }

    /// An exponential falloff curve with adjustable steepness.
    ///
    /// Influence starts at full strength and drops off exponentially toward 0 as the point
    /// approaches `influenceRadius`. Higher exponents create sharper drop-offs.
    /// The falloff value is multiplied by `maxMovement` to determine movement.
    ///
    /// - Parameter exponent: Controls how sharply the falloff drops. A value of 1 is linear, >1 is sharper.
    static func exponential(_ exponent: Double = 2.0) -> Self {
        Self(.exponential(exponent: exponent))
    }
}

@available(macOS 15, *)
public extension Falloff where Self == ExpressionFalloff {
    static func expression(_ expression: Expression<Double, Double>) -> Self {
        Self(expression: expression)
    }
}
