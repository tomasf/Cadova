import Foundation

/// A layout container that arranges geometries along a specific axis.
///
/// `Stack` positions geometries one after another along a given axis with optional spacing,
/// while also allowing alignment relative to the origin in the remaining axes.
///
/// Each item is translated based on its bounds to avoid overlap, and alignment is used to determine
/// how items are positioned on the axes *not* used for stacking.
///
/// - Important: The alignment only affects the axes that are not used for stacking. For example,
///   when stacking along the `.z` axis, alignment controls how items are positioned along `.x` and `.y`
///   relative to the origin.
///
public struct Stack <D: Dimensionality> {
    private let items: @Sendable () -> [D.Geometry]
    private let axis: D.Axis
    private let spacing: Double
    private let alignment: D.Alignment

    fileprivate init(
        axis: D.Axis,
        spacing: Double,
        alignment: [D.Alignment],
        content: @Sendable @escaping () -> [D.Geometry]
    ) {
        self.items = content
        self.axis = axis
        self.spacing = spacing
        self.alignment = .init(merging: alignment)
            .with(axis: axis, as: .min)
    }
}

extension Stack: Geometry {
    /// Initializes a new stack layout along the specified axis.
    ///
    /// This initializer creates a stack of geometries with optional spacing between them,
    /// and alignment relative to the origin on non-stacking axes.
    ///
    /// - Parameters:
    ///   - axis: The axis to stack along (`.x`, `.y`, or `.z` depending on dimensionality).
    ///   - spacing: The spacing in millimeters between items. Defaults to `0`.
    ///   - alignment: One or more alignment values for the *non-stacking* axes.
    ///     For example, in a `.z` stack, `.centerX` and `.centerY` will center items in the XY plane.
    ///     Axes that are neither the stack axis nor explicitly specified in `alignment` are left unchanged.
    ///   - content: A closure that returns the geometries to be stacked.
    ///
    /// ## Example
    /// ```swift
    /// Stack(.z, spacing: 2, alignment: .centerX, .minY) {
    ///     Cylinder(radius: 5, height: 1)
    ///     Box([10, 10, 3])
    /// }
    /// ```
    ///
    /// This stacks a cylinder and a box along the Z-axis, centers them along the X-axis,
    /// and aligns them to the bottom on the Y-axis.
    public init(
        _ axis: D.Axis,
        spacing: Double = 0,
        alignment: D.Alignment...,
        @SequenceBuilder<D> content: @Sendable @escaping () -> [D.Geometry]
    ) {
        self.init(axis: axis, spacing: spacing, alignment: alignment, content: content)
    }

    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let union = try await Union {
            var offset = 0.0
            for geometry in items() {
                let concreteResult = try await context.result(for: geometry, in: environment)

                if !concreteResult.concrete.isEmpty {
                    let box = D.BoundingBox(concreteResult.concrete.bounds)
                    geometry.translated(box.translation(for: alignment) + .init(axis, value: offset))
                    offset += box.size[axis] + spacing
                }
            }
        }
        return try await context.buildResult(for: union, in: environment)
    }
}
