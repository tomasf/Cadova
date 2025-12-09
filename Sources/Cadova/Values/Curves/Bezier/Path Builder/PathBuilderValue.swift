import Foundation

/// A type that can be used as a coordinate value in path builder functions.
///
/// This protocol enables flexible coordinate specification in path construction. Values
/// conforming to this protocol can represent absolute positions, relative offsets, or
/// indicate that a coordinate should remain unchanged.
///
/// `Double` conforms to this protocol and provides additional modifiers:
/// - Use a raw `Double` to specify a value that follows the path's default positioning mode
/// - Use `.relative` suffix to explicitly mark a value as a relative offset
/// - Use `.absolute` suffix to explicitly mark a value as an absolute position
/// - Use `.unchanged` to keep the coordinate at its current value
///
/// - Example:
///   ```swift
///   BezierPath2D(from: [0, 0], mode: .absolute) {
///       line(x: 100, y: 50)              // Both absolute (follows default)
///       line(x: 10.relative, y: 20)      // X is relative (+10), Y is absolute (20)
///       line(x: .unchanged, y: 100)      // X stays at 10, Y goes to 100
///   }
///   ```
///
/// - SeeAlso: ``PathBuilderPositioning``
///
public protocol PathBuilderValue: Sendable {}

extension Double: PathBuilderValue {
    /// Returns this value marked as a relative offset.
    ///
    /// When used in a path builder function, this value will be interpreted as an offset
    /// from the current position, regardless of the path's default positioning mode.
    ///
    /// - Example:
    ///   ```swift
    ///   line(x: 10.relative, y: 5.relative)  // Move by (10, 5) from current position
    ///   ```
    ///
    public var relative: any PathBuilderValue {
        PositionedValue(value: self, mode: .relative)
    }

    /// Returns this value marked as an absolute position.
    ///
    /// When used in a path builder function, this value will be interpreted as an absolute
    /// coordinate in the path's coordinate system, regardless of the path's default
    /// positioning mode.
    ///
    /// - Example:
    ///   ```swift
    ///   line(x: 100.absolute, y: 50.absolute)  // Go to point (100, 50)
    ///   ```
    ///
    public var absolute: any PathBuilderValue {
        PositionedValue(value: self, mode: .absolute)
    }
}

public extension PathBuilderValue where Self == Double {
    /// A sentinel value indicating that a coordinate should remain at its current value.
    ///
    /// Use this when you want to change only some coordinates while leaving others unchanged.
    /// This is equivalent to `0.relative` but communicates intent more clearly.
    ///
    /// - Example:
    ///   ```swift
    ///   line(x: 100, y: .unchanged)  // Move to X=100, keep Y at current value
    ///   line(x: .unchanged, y: 50)   // Keep X, move to Y=50
    ///   ```
    ///
    static var unchanged: any PathBuilderValue { 0.relative }
}

internal struct PositionedValue: PathBuilderValue {
    var value: Double
    var mode: PathBuilderPositioning?

    func value(relativeTo base: Double, defaultMode: PathBuilderPositioning) -> Double {
        switch mode ?? defaultMode {
        case .relative: base + value
        case .absolute: value
        }
    }

    func withDefaultMode(_ defaultMode: PathBuilderPositioning) -> PositionedValue {
        .init(value: value, mode: mode ?? defaultMode)
    }
}

internal extension PathBuilderValue {
    var positionedValue: PositionedValue {
        if let self = self as? Double {
            PositionedValue(value: self, mode: nil)
        } else if let self = self as? PositionedValue {
            self
        } else {
            preconditionFailure("Unknown BezierBuilderValue type.")
        }
    }
}
