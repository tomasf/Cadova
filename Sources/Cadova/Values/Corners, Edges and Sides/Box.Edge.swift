import Foundation

public extension Box {
    /// Represents an edge of a 3D box along a specified axis, defined by
    /// positions along the two remaining axes.
    struct Edge: Hashable {
        /// The primary axis along which the edge runs (X, Y, or Z).
        public let axis: Axis3D

        internal let x: AxisDirection
        internal let y: AxisDirection
        internal let z: AxisDirection

        internal init(axis: Axis3D, x: AxisDirection = .min, y: AxisDirection = .min, z: AxisDirection = .min) {
            self.axis = axis
            self.x = axis == .x ? .min : x
            self.y = axis == .y ? .min : y
            self.z = axis == .z ? .min : z
        }

        /// The unit offset to the edge.
        ///
        /// This vector can be scaled by box dimensions to obtain the actual offset
        /// from the origin to this edge in 3D space.
        public var unitOffset: Vector3D {
            .init(x.unit, y.unit, z.unit)
        }


        /// Returns the corner point associated with this edge in a specified primary axis direction.
        ///
        /// - Parameter direction: The primary axis direction to define the corner location (`.positive` or `.negative`).
        /// - Returns: A `Corner` representing the intersection of this edge with the specified direction along its primary axis.
        ///
        /// This method combines the two directions that define this edge’s location on
        /// the perpendicular axes with the specified direction along the primary axis, yielding
        /// a unique `Corner` in the box.
        public func corner(in direction: AxisDirection) -> Corner {
            Corner(
                x: axis == .x ? direction : x,
                y: axis == .y ? direction : y,
                z: axis == .z ? direction : z
            )
        }
    }

    typealias Edges = Set<Edge>
}

fileprivate extension AxisDirection {
    var unit: Double {
        self == .positive ? 1 : 0
    }
}

public extension Box.Edge {
    /// Creates an edge along the X-axis, specifying positions along the Y and Z axes.
    ///
    /// - Parameters:
    ///   - ySide: The position along the Y-axis (`.min` or `.max`).
    ///   - zSide: The position along the Z-axis (`.min` or `.max`).
    /// - Returns: An `Edge` instance running along the X-axis.
    static func alongX(ySide: AxisDirection, zSide: AxisDirection) -> Self {
        .init(axis: .x, y: ySide, z: zSide)
    }

    /// Creates an edge along the Y-axis, specifying positions along the X and Z axes.
    ///
    /// - Parameters:
    ///   - xSide: The position along the X-axis (`.min` or `.max`).
    ///   - zSide: The position along the Z-axis (`.min` or `.max`).
    /// - Returns: An `Edge` instance running along the Y-axis.
    static func alongY(xSide: AxisDirection, zSide: AxisDirection) -> Self {
        .init(axis: .y, x: xSide, z: zSide)
    }

    /// Creates an edge along the Z-axis, specifying positions along the X and Y axes.
    ///
    /// - Parameters:
    ///   - xSide: The position along the X-axis (`.min` or `.max`).
    ///   - ySide: The position along the Y-axis (`.min` or `.max`).
    /// - Returns: An `Edge` instance running along the Z-axis.
    static func alongZ(xSide: AxisDirection, ySide: AxisDirection) -> Self {
        .init(axis: .z, x: xSide, y: ySide)
    }
}

internal extension Box.Edges {
    static var all: Self {
        Set(Axis3D.allCases.flatMap { axis in
            AxisDirection.allCases.flatMap { x in
                AxisDirection.allCases.flatMap { y in
                    AxisDirection.allCases.map { z in
                        Box.Edge(axis: axis, x: x, y: y, z: z)
                    }
                }
            }
        })
    }
}
