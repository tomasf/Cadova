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

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil) where D == D2 {
        values = .init(x: x, y: y)
    }

    public init(x: AxisAlignment? = nil, y: AxisAlignment? = nil, z: AxisAlignment? = nil) where D == D3 {
        values = .init(x: x, y: y, z: z)
    }

    public init(all value: AxisAlignment?) {
        values = .init { _ in value }
    }

    internal init(merging alignments: [Self]) {
        values = .init { index in
            alignments.compactMap { $0[index] }.last
        }
    }

    public subscript(axis: D.Axis) -> AxisAlignment? {
        values[axis]
    }

    public func with(axis: D.Axis, as newValue: AxisAlignment) -> Self {
        .init(values.map { $0 == axis ? newValue : $1 })
    }

    internal var factors: D.Vector {
        values.map { $0?.factor ?? 0 }.vector
    }

    internal func defaultingToOrigin() -> Self {
        .init(values.map { $0 ?? .min })
    }

    internal var hasEffect: Bool {
        values.contains { $0 != nil }
    }
}

public typealias GeometryAlignment2D = GeometryAlignment<D2>
public typealias GeometryAlignment3D = GeometryAlignment<D3>

internal extension [GeometryAlignment2D] {
    var merged: GeometryAlignment2D { .init(merging: self) }
}

internal extension [GeometryAlignment3D] {
    var merged: GeometryAlignment3D { .init(merging: self) }
}
