import Foundation

public extension GeometryEvaluator {
    /// Splits `geometry` into two parts along the specified plane.
    ///
    /// This is the evaluator equivalent of `Geometry3D.split(along:reader:)`. Instead of passing
    /// both parts to a closure, they're returned directly, so they can be read or composed alongside
    /// other evaluator calls in the same block.
    ///
    /// ```swift
    /// model.evaluating { g, eval in
    ///     let (over, under) = await eval.split(g, along: .z(3))
    ///     let overBounds = await eval.bounds(of: over)
    ///     // ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - geometry: The geometry to split.
    ///   - plane: The `Plane` used to split the geometry.
    /// - Returns: The two parts, on opposite sides of the plane. `over` is the side facing the
    ///   direction of the plane's normal, matching the first parameter of `split(along:reader:)`.
    ///
    func split(_ geometry: any Geometry3D, along plane: Plane) async -> (over: any Geometry3D, under: any Geometry3D) {
        (
            GeometryNodeTransformer(body: geometry) { .trim($0, plane: plane) },
            GeometryNodeTransformer(body: geometry) { .trim($0, plane: plane.flipped) }
        )
    }

    /// Splits `geometry` into two parts along the specified line.
    ///
    /// This is the evaluator equivalent of `Geometry2D.split(along:reader:)`. Instead of passing
    /// both parts to a closure, they're returned directly, so they can be read or composed alongside
    /// other evaluator calls in the same block.
    ///
    /// ```swift
    /// shape.evaluating { g, eval in
    ///     let (right, left) = await eval.split(g, along: .y)
    ///     let rightBounds = await eval.bounds(of: right)
    ///     // ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - geometry: The geometry to split.
    ///   - line: The `Line2D` used to split the geometry.
    /// - Returns: The two parts, on opposite sides of the line. `right` is the side facing the
    ///   clockwise normal of the line (right side relative to the line's direction), matching the
    ///   first parameter of `split(along:reader:)`.
    ///
    func split(_ geometry: any Geometry2D, along line: Line2D) async -> (right: any Geometry2D, left: any Geometry2D) {
        (geometry.trimmed(along: line), geometry.trimmed(along: line.flipped))
    }

    /// Splits `geometry` using a mask geometry.
    ///
    /// This is the evaluator equivalent of `Geometry3D.split(with:result:)`. Instead of passing
    /// both parts to a closure, they're returned directly, so they can be read or composed alongside
    /// other evaluator calls in the same block.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to split.
    ///   - mask: A closure that builds the mask geometry.
    /// - Returns: The parts of `geometry` inside and outside the mask.
    ///
    func split(
        _ geometry: any Geometry3D,
        @GeometryBuilder3D with mask: @Sendable @escaping () -> any Geometry3D
    ) async -> (inside: any Geometry3D, outside: any Geometry3D) {
        (geometry.intersecting(mask()), geometry.subtracting(mask()))
    }

    /// Splits `geometry` using a mask geometry.
    ///
    /// This is the evaluator equivalent of `Geometry2D.split(with:result:)`. Instead of passing
    /// both parts to a closure, they're returned directly, so they can be read or composed alongside
    /// other evaluator calls in the same block.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to split.
    ///   - mask: A closure that builds the mask geometry.
    /// - Returns: The parts of `geometry` inside and outside the mask.
    ///
    func split(
        _ geometry: any Geometry2D,
        @GeometryBuilder2D with mask: @Sendable @escaping () -> any Geometry2D
    ) async -> (inside: any Geometry2D, outside: any Geometry2D) {
        (geometry.intersecting(mask()), geometry.subtracting(mask()))
    }

    /// Splits `geometry` into two parts using axis-aligned ranges.
    ///
    /// This is the evaluator equivalent of `Geometry3D.split(x:y:z:reader:)`. Instead of passing
    /// both parts to a closure, they're returned directly, so they can be read or composed alongside
    /// other evaluator calls in the same block.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to split.
    ///   - x: Optional range along the x-axis. If `nil`, the region is unbounded in the x direction.
    ///   - y: Optional range along the y-axis. If `nil`, the region is unbounded in the y direction.
    ///   - z: Optional range along the z-axis. If `nil`, the region is unbounded in the z direction.
    /// - Returns: The parts of `geometry` inside and outside the given ranges. Both are empty if
    ///   `geometry` is empty.
    ///
    func split(
        _ geometry: any Geometry3D,
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) async -> (inside: any Geometry3D, outside: any Geometry3D) {
        guard let bounds = await bounds(of: geometry) else { return (Empty(), Empty()) }
        return await split(geometry, with: { bounds.within(x: x, y: y, z: z, margin: 1).mask })
    }

    /// Splits `geometry` into two parts using axis-aligned ranges.
    ///
    /// This is the evaluator equivalent of `Geometry2D.split(x:y:reader:)`. Instead of passing
    /// both parts to a closure, they're returned directly, so they can be read or composed alongside
    /// other evaluator calls in the same block.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to split.
    ///   - x: Optional range along the x-axis. If `nil`, the region is unbounded in the x direction.
    ///   - y: Optional range along the y-axis. If `nil`, the region is unbounded in the y direction.
    /// - Returns: The parts of `geometry` inside and outside the given ranges. Both are empty if
    ///   `geometry` is empty.
    ///
    func split(
        _ geometry: any Geometry2D,
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil
    ) async -> (inside: any Geometry2D, outside: any Geometry2D) {
        guard let bounds = await bounds(of: geometry) else { return (Empty(), Empty()) }
        return await split(geometry, with: { bounds.within(x: x, y: y, margin: 1).mask })
    }
}
