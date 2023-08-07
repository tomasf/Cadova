import Foundation

/// A 3D box shape with rounded corners, providing options for either single-axis rounding or full 3D rounding.
///
/// `RoundedBox` offers two distinct ways to round the corners of a 3D box:
/// - **Single-Axis Rounding:** Allows for rounding the corners along a specific axis (x, y, or z). This is equivalent to an extruded `RoundedRectangle`.
/// - **3D Rounding:** Applies a uniform rounding effect to all eight corners of the box in all three dimensions. A single corner radius is applied uniformly to all corners.
///
/// ## Example
/// ### Single-Axis Rounding
/// ```swift
/// let box = RoundedBox([10, 20, 5], axis: .y, cornerRadius: 5)
/// ```
///
/// ### 3D Rounding
/// ```swift
/// let box = RoundedBox([10, 20, 5], cornerRadius: 5)
/// ```

public struct RoundedBox: Shape3D {
    internal typealias CornerRadii = RoundedRectangle.CornerRadii
    public typealias CornerStyle = RoundedRectangle.CornerStyle
    private let implementation: Geometry3D
    
    // MARK: - Single axis
    private init(_ size: Vector3D, center: Axes3D, axis: Axis3D, style: CornerStyle, cornerRadii radii: CornerRadii) {
        self.implementation = RoundedBoxSingleAxis(size: size, cornerStyle: style, axis: axis, radii: radii)
            .translated((size / 2).setting(axes: center, to: 0))
    }

    /// Initializes a rounded box along a single axis.
    ///
    /// - Parameters:
    ///   - size: The dimensions of the box in all three axes.
    ///   - center: Defines which axes are centered at the origin.
    ///   - axis: Specifies the axis to round the corners.
    ///   - style: Determines the shape of the rounded corners.
    ///   - cornerRadius: The radius of the corners.
    public init(_ size: Vector3D, center: Axes3D = .none, axis: Axis3D, style: CornerStyle = .circular, cornerRadius: Double) {
        self.init(size, center: center, axis: axis, style: style, cornerRadii: .init(cornerRadius))
    }

    /// Initializes a rounded box along a single axis with specific corner radii.
    ///
    /// - Parameters:
    ///   - size: The dimensions of the box in all three axes.
    ///   - center: Defines which axes are centered at the origin.
    ///   - axis: Specifies the axis to round the corners.
    ///   - style: Determines the shape of the rounded corners.
    ///   - radii: An array of corner radii for each corner. The array must contain exactly 4 elements.
    public init(_ size: Vector3D, center: Axes3D = .none, axis: Axis3D, style: CornerStyle = .circular, cornerRadii radii: [Double]) {
        precondition(radii.count == 4)
        self.init(size, center: center, axis: axis, style: style, cornerRadii: .init(arrayLiteral: radii[0], radii[1], radii[2], radii[3]))
    }
    
    // MARK: - 3D

    /// Initializes a box with all eight corners rounded
    ///
    /// - Parameters:
    ///   - size: The dimensions of the box in all three axes.
    ///   - center: Defines which axes are centered at the origin.
    ///   - radius: The radius of the corners for all three axes.
    public init(_ size: Vector3D, center: Axes3D = .none, cornerRadius radius: Double) {
        self.implementation = RoundedBox3D(size: size, cornerRadius: radius)
            .translated((size / 2).setting(axes: center, to: 0))
    }
    
    public var body: Geometry3D {
        implementation
    }
}
