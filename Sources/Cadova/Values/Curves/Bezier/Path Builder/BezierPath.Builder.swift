import Foundation

public extension BezierPath {
    /// A result builder type for constructing Bezier paths from component functions.
    typealias Builder = ArrayBuilder<BezierPath<V>.Component>

    /// Creates a Bezier path using a declarative builder syntax.
    ///
    /// This initializer enables a DSL-style approach to constructing paths using global functions
    /// like ``line(x:y:)``, ``curve(controlX:controlY:endX:endY:)``, and ``clockwiseArc(center:angle:)``.
    ///
    /// - Parameters:
    ///   - from: The starting point of the path. Defaults to the origin.
    ///   - defaultMode: The default positioning mode for coordinates. When set to `.absolute`,
    ///     coordinate values represent absolute positions. When set to `.relative`, values
    ///     represent offsets from the current point. Defaults to `.absolute`.
    ///   - builder: A closure that returns an array of path components using the builder syntax.
    ///
    /// - Example:
    ///   ```swift
    ///   let path = BezierPath2D(from: [10, 4], mode: .relative) {
    ///       line(x: 22, y: 1)
    ///       line(x: 2)
    ///       curve(
    ///           controlX: 7, controlY: 12,
    ///           endX: 77, endY: 18
    ///       )
    ///   }
    ///   ```
    ///
    /// - SeeAlso: ``PathBuilderPositioning``
    ///
    init(from: V = .zero, mode defaultMode: PathBuilderPositioning = .absolute, @Builder builder: () -> [Component]) {
        var path = BezierPath(startPoint: from)
        for component in builder() {
            path = component.appendAction(path, defaultMode)
        }
        self = path
    }

    /// A single segment or operation that can be added to a Bezier path.
    ///
    /// Components represent individual path segments such as lines, curves, or arcs.
    /// They are created using global functions like ``line(x:y:)``, ``curve(controlX:controlY:endX:endY:)``,
    /// and ``clockwiseArc(center:angle:)``, and are combined using the ``BezierPath/Builder`` syntax.
    ///
    /// Each component can have its positioning mode overridden using the ``relative`` or ``absolute``
    /// properties, regardless of the path's default mode.
    ///
    struct Component {
        internal let appendAction: (BezierPath, PathBuilderPositioning) -> BezierPath

        internal init(appendAction: @escaping (BezierPath, PathBuilderPositioning) -> BezierPath) {
            self.appendAction = appendAction
        }

        internal init(continuousDistance: Double? = nil, _ points: [PathBuilderVector<V>]) {
            self.init { path, defaultMode in
                let start = path.endPoint
                var controlPoints: [V] = []

                if let continuousDistance {
                    guard let direction = path.endDirection else {
                        preconditionFailure("Adding a continuous segment requires a previous segment to match")
                    }
                    controlPoints.append(start + direction.unitVector * continuousDistance)
                }

                controlPoints += points.map {
                    $0.value(relativeTo: start, defaultMode: defaultMode)
                }

                return path.addingCurve(controlPoints)
            }
        }

        internal func withDefaultMode(_ mode: PathBuilderPositioning) -> Self {
            let oldAction = self.appendAction
            return Self { path, _ in
                oldAction(path, mode)
            }
        }

        /// Returns a copy of this component that interprets all coordinates as relative offsets.
        ///
        /// Use this to override the path's default positioning mode for a specific component.
        ///
        /// - Example:
        ///   ```swift
        ///   BezierPath2D(from: [0, 0], mode: .absolute) {
        ///       line(x: 100, y: 0)           // Absolute: goes to (100, 0)
        ///       line(x: 10, y: 10).relative  // Relative: moves by (10, 10) to (110, 10)
        ///   }
        ///   ```
        ///
        public var relative: Component { withDefaultMode(.relative) }

        /// Returns a copy of this component that interprets all coordinates as absolute positions.
        ///
        /// Use this to override the path's default positioning mode for a specific component.
        ///
        /// - Example:
        ///   ```swift
        ///   BezierPath2D(from: [0, 0], mode: .relative) {
        ///       line(x: 10, y: 10)           // Relative: moves by (10, 10) to (10, 10)
        ///       line(x: 50, y: 50).absolute  // Absolute: goes to (50, 50)
        ///   }
        ///   ```
        ///
        public var absolute: Component { withDefaultMode(.absolute) }
    }
}

/// Specifies how coordinate values in path builder functions are interpreted.
///
/// This enum controls whether numeric values represent absolute positions in the coordinate
/// system or relative offsets from the current path position.
///
/// - SeeAlso: ``BezierPath/init(from:mode:builder:)``
///
public enum PathBuilderPositioning: Sendable {
    /// Coordinate values represent absolute positions in the coordinate system.
    ///
    /// For example, `line(x: 100, y: 50)` draws a line to the point (100, 50).
    case absolute

    /// Coordinate values represent offsets from the current path position.
    ///
    /// For example, `line(x: 10, y: 5)` draws a line 10 units right and 5 units up
    /// from the current position.
    case relative
}
