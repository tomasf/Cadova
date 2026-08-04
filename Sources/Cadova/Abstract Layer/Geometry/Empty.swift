import Foundation

/// A geometry containing no shape.
///
/// Building `Empty` always produces empty output. It's useful as a placeholder or fallback value
/// wherever geometry is expected but there's nothing to show.
public struct Empty<D: Dimensionality>: Geometry {
    /// Creates an empty geometry.
    public init() {}

    public func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> _BuildResult<D> {
        .init(.empty)
    }
}
