import Foundation

/// Represents how a geometry should be aligned relative to the coordinate system’s origin.
///
/// `GeometryAlignment` lets you specify alignment preferences along each axis of a geometry.
/// These preferences are expressed using `AxisAlignment` values such as `.min`, `.mid`, or `.max`,
/// which determine how the geometry’s bounding box should be positioned in relation to the origin.
///
/// This type is used in layout and transformation contexts such as `Stack`, `.aligned(at:)`, or other
/// compositional operations that arrange or shift geometry based on alignment rules.
///
/// Alignment is not a geometric transformation by itself—it is a configuration that controls how
/// geometry should be translated in layout-aware operations.
///
/// ### Behavior
/// - You can align along any subset of the available axes (e.g., just `x`, or `x` and `z`).
/// - Use `.none` for no alignment, or `.center` to center along all axes.
///
/// ### Example
/// Center a shape horizontally and align its bottom edge to Y = 0:
/// ```swift
/// Rectangle(x: 20, y: 10)
///     .aligned(at: .centerX, .bottom)
/// ```
///
/// > Note: Alignment operates on the bounding box of the geometry and affects how it is
/// positioned relative to the origin during layout or stacking operations.
///
/// See also: `AxisAlignment`, `Geometry.aligned(at:)`, and `Stack`.
///
public struct GeometryAlignment<D: Dimensionality>: Equatable, Sendable {
    internal let values: DimensionalValues<AxisAlignment?, D>

    private init(_ values: DimensionalValues<AxisAlignment?, D>) {
        self.values = values
    }

    /// Creates a 2D alignment with the specified values for each axis.
    ///
    /// - Parameters:
    ///   - x: The alignment along the X axis, or `nil` for no alignment.
    ///   - y: The alignment along the Y axis, or `nil` for no alignment.
    ///
    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) where D == D2 {
        values = .init(x: x, y: y)
    }

    /// Creates a 3D alignment with the specified values for each axis.
    ///
    /// - Parameters:
    ///   - x: The alignment along the X axis, or `nil` for no alignment.
    ///   - y: The alignment along the Y axis, or `nil` for no alignment.
    ///   - z: The alignment along the Z axis, or `nil` for no alignment.
    ///
    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil, z: AxisAlignment? = nil) where D == D3 {
        values = .init(x: x, y: y, z: z)
    }

    /// Creates an alignment with the same value for all axes.
    ///
    /// - Parameter value: The alignment to apply to all axes, or `nil` for no alignment.
    ///
    public init(all value: AxisAlignment?) {
        values = .init { _ in value }
    }

    internal init(merging alignments: [Self]) {
        values = .init { index in
            alignments.compactMap { $0[index] }.last
        }
    }

    /// Returns the alignment for the specified axis.
    public subscript(axis: D.Axis) -> AxisAlignment? {
        values[axis]
    }

    /// Returns a copy with the alignment for one axis changed.
    ///
    /// - Parameters:
    ///   - axis: The axis to modify.
    ///   - newValue: The new alignment for that axis.
    /// - Returns: A new alignment with the specified axis updated.
    ///
    public func with(axis: D.Axis, as newValue: AxisAlignment) -> Self {
        .init(values.map { $0 == axis ? newValue : $1 })
    }

    internal var factors: D.Vector {
        values.map { $0?.fraction ?? 0 }.vector
    }

    internal func defaultingToOrigin() -> Self {
        .init(values.map { $0 ?? .min })
    }

    internal var hasEffect: Bool {
        values.contains { $0 != nil }
    }
}

/// A 2D geometry alignment.
public typealias GeometryAlignment2D = GeometryAlignment<D2>

/// A 3D geometry alignment.
public typealias GeometryAlignment3D = GeometryAlignment<D3>

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}
