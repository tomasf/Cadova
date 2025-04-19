import Foundation

public struct Stack<D: Dimensionality> {
    private let items: [D.Geometry]
    private let axis: D.Axis
    private let spacing: Double
    private let alignment: D.Alignment

    @Environment private var environment

    fileprivate init(axis: D.Axis, spacing: Double, alignment: [D.Alignment], content: @escaping () -> [D.Geometry]
    ) {
        self.items = content()
        self.axis = axis
        self.spacing = spacing
        self.alignment = .init(merging: alignment)
            .defaultingToOrigin()
            .with(axis: axis, as: .min)
    }
}

extension Stack: Geometry {
    /// Creates a stack of geometries aligned along the specified axis with optional spacing and alignment.
    ///
    /// - Parameters:
    ///   - axis: The axis along which the geometries are stacked.
    ///   - spacing: The spacing between stacked geometries. Default is `0`.
    ///   - alignment: The alignment of the stack. Can be merged from multiple alignment options.
    ///   - content: A closure generating geometries to stack.
    public init(
        _ axis: D.Axis,
        spacing: Double = 0,
        alignment: D.Alignment...,
        @SequenceBuilder<D> content: @escaping () -> [D.Geometry]
    ) {
        self.init(axis: axis, spacing: spacing, alignment: alignment, content: content)
    }

    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        var offset = 0.0
        return await Union {
            for geometry in items {
                let result = await geometry.build(in: environment, context: context)
                let primitive = await context.geometry(for: result.expression)
                let box = D.BoundingBox(primitive.bounds)
                geometry.translated(box.translation(for: alignment) + .init(axis, value: offset))
                offset += box.size[axis] + spacing
            }
        }.build(in: environment, context: context)
}
}
