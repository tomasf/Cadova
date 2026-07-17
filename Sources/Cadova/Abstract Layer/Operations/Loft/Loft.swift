import Foundation

/// A 3D shape constructed by interpolating between a series of 2D cross-sections placed along a path.
///
/// Lofting is a modeling technique that creates a smooth transition between multiple 2D shapes placed at different
/// points along a path (a straight vertical axis by default, or any 3D `ParametricCurve`). Each 2D shape forms a
/// cross-section of the final 3D shape, and the space between these sections is filled in by connecting them using
/// a resampling-based interpolation method.
///
/// The loft uses a resampled interpolation strategy: each shape is resampled to have matching vertex counts across
/// sections. This allows precise matching of complex shapes, including those with holes. All sections must have
/// compatible topology; that is, each section must have the same number of top-level shapes, and each shape must
/// have the same number of holes (if any), and so on.
///
/// The `ShapingFunction` determines how intermediate sections are distributed and how the transition between each
/// pair of cross-sections progresses. By default, the interpolation is linear, meaning each intermediate section is
/// evenly spaced in both distance and shape between the source and target sections. By supplying a different
/// shaping function, you can control the interpolation rate—such as using "ease in", "ease out", or a custom curve.
/// This can be used to create organic bulges, tapering, or other stylized transitions between sections. Individual
/// sections can override this function by specifying their own shaping function in the corresponding `Section(...)`
/// call.
///
/// Each section is specified using a distance along the path and a 2D shape (any Geometry2D-conforming type). At
/// least two sections must be provided.
///
/// - Example:
///   ```swift
///   Loft {
///       Section(at: 0) {
///           Circle(radius: 10)
///       }
///       Section(at: 20) {
///           Rectangle(20)
///               .aligned(at: .center)
///       }
///   }
///   ```
///   This creates a lofted 3D shape by interpolating between a circle at the base and a square at the top.
///
/// - Example with three sections. Each section has one hole each, fulfilling the requirement for compatible topology.
///   ```swift
///   Loft {
///       Section(at: 0) {
///           Circle(diameter: 20)
///               .subtracting {
///                   Circle(diameter: 12)
///               }
///       }
///       Section(at: 30) {
///           Rectangle(x: 25, y: 6)
///               .aligned(at: .center)
///               .repeated(in: 0°..<180°, count: 2)
///               .subtracting {
///                   RegularPolygon(sideCount: 8, circumradius: 2)
///               }
///       }
///       Section(at: 35) {
///           Circle(diameter: 12)
///               .subtracting {
///                   Circle(diameter: 10)
///               }
///       }
///   }
///   ```
///
/// - Example lofting along a 3D path:
///   ```swift
///   Loft(along: someBentPath) {
///       Section(at: 0) {
///           Circle(radius: 10)
///       }
///       Section(at: 40) {
///           Rectangle(20)
///               .aligned(at: .center)
///       }
///   }
///   ```
///   `Section(at:)` values are distances traveled along the path, and each cross-section is automatically oriented
///   to follow the path's direction.
///
public struct Loft: Geometry {
    public typealias D = D3

    internal let path: OpaqueParametricCurve<Vector3D>
    internal let sections: [Section]
    internal let shapingFunction: ShapingFunction
    internal let reference: Direction2D
    internal let target: ReferenceTarget

    /// Creates a lofted 3D geometry by interpolating between a series of 2D cross-sections placed along a path,
    /// using a resampling-based approach.
    ///
    /// Resampling allows precise matching of complex shapes, including those with holes. All sections must have
    /// compatible topology: each section must have the same number of top-level shapes, and each shape must have
    /// the same number of holes (if any), and so on.
    ///
    /// - Parameters:
    ///   - path: The path the loft's cross-sections should follow. This can be a 2D or 3D parametric curve. If 2D,
    ///     the path is interpreted as lying in the XY plane. `Section(at:)` distances are measured as arc length
    ///     traveled along this path, starting at 0.
    ///   - interpolation: The shaping function to use between sections. Defaults to `.linear`. Individual sections
    ///     can override this by specifying their own shaping function in `Section(...)`.
    ///   - reference: A direction within each 2D cross-section (usually `.down` or `.right`) that should be kept
    ///     facing toward `target` as the loft follows the path. This affects the rotation of each cross-section.
    ///     There's no universally sensible default: what's natural for a roughly-horizontal path (e.g. facing
    ///     gravity-down) can be degenerate for a vertical one, so this must be specified explicitly.
    ///   - target: The 3D direction, point, or line that `reference` should point toward at every section. This
    ///     controls the orientation of the cross-sections along the path.
    ///   - sections: A builder that returns the list of sections. Each section must have a distance and a 2D shape.
    ///
    public init<Path: ParametricCurve>(
        along path: Path,
        interpolation: ShapingFunction = .linear,
        pointing reference: Direction2D,
        toward target: ReferenceTarget,
        @SectionBuilder sections: () -> [Section]
    ) {
        let resolved = Loft.resolvedSections(sections())
        self.init(
            path: OpaqueParametricCurve(path.curve3D),
            sections: resolved,
            shapingFunction: interpolation,
            reference: reference,
            target: target
        )
    }

    /// Creates a lofted 3D geometry by interpolating between a series of 2D cross-sections stacked along an
    /// implicit straight vertical (Z) axis, using a resampling-based approach.
    ///
    /// Resampling allows precise matching of complex shapes, including those with holes. All sections must have
    /// compatible topology: each section must have the same number of top-level shapes, and each shape must have
    /// the same number of holes (if any), and so on.
    ///
    /// Cross-sections are not rotated as they stack — this initializer always produces a plain, untwisted stack.
    /// If you need sections to track an off-axis target as they rise (e.g. always facing a fixed point or line),
    /// use `init(along:interpolation:pointing:toward:sections:)` with an explicit vertical path instead.
    ///
    /// - Parameters:
    ///   - interpolation: The shaping function to use between sections. Defaults to `.linear`. Individual sections
    ///     can override this by specifying their own shaping function in `Section(...)`.
    ///   - sections: A builder that returns the list of sections. Each section must have a Z height and a 2D shape.
    ///
    public init(
        interpolation: ShapingFunction = .linear,
        @SectionBuilder sections: () -> [Section]
    ) {
        let resolved = Loft.resolvedSections(sections())
        let (path, shifted) = Loft.implicitPath(for: resolved)
        self.init(path: path, sections: shifted, shapingFunction: interpolation, reference: .negativeY, target: .direction(.negativeY))
    }

    internal init(path: OpaqueParametricCurve<Vector3D>, sections: [Section], shapingFunction: ShapingFunction, reference: Direction2D, target: ReferenceTarget) {
        self.path = path
        self.sections = sections
        self.shapingFunction = shapingFunction
        self.reference = reference
        self.target = target
    }
}

internal extension Loft {
    /// Resolves a builder's raw sections (which may include `atRelative:` offsets or ranges, in original
    /// declaration order) into a sorted, absolute-distance list. Offsets are resolved sequentially against
    /// the previously resolved section's distance, matching the original declaration order — sorting by
    /// distance happens only after every offset has been resolved.
    static func resolvedSections(_ sections: [Section]) -> [Section] {
        var lastDistance = 0.0
        var resolved: [Section] = []
        for section in sections {
            resolved.append(contentsOf: section.resolved(lastDistance: &lastDistance))
        }
        let sorted = resolved.sorted { $0.distance < $1.distance }
        precondition(sorted.count >= 2, "Loft requires at least two sections")
        return sorted
    }

    /// Builds an implicit straight vertical (Z) path spanning the given sections' distances, and shifts the
    /// sections so their distances become non-negative arc lengths along that path. This makes a no-`along:`
    /// `Loft` behave identically to today's Z-stacking behavior: for a section at Z height `d`, its position
    /// after this shift is `d - baseline`, and the implicit line's `point(at:)` for that arc length is exactly
    /// `Vector3D(0, 0, d)`.
    static func implicitPath(for sections: [Section]) -> (path: OpaqueParametricCurve<Vector3D>, sections: [Section]) {
        let baseline = sections.first!.distance
        let span = sections.last!.distance - baseline
        precondition(span > 0, "Loft requires sections at more than one distance")
        let line = BezierPath3D(linesBetween: [Vector3D(0, 0, baseline), Vector3D(0, 0, baseline + span)])
        let shifted = sections.map {
            Section(distance: $0.distance - baseline, transition: $0.transition, geometry: $0.geometry)
        }
        return (OpaqueParametricCurve(line), shifted)
    }
}

public extension Geometry2D {
    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two sections.
    ///
    /// The loft uses a resampling-based interpolation strategy: each shape is resampled to have matching vertex counts
    /// across sections. Both sections must have compatible topology.
    ///
    /// - Parameters:
    ///   - shapingFunction: The shaping function applied to the transition. Defaults to `.linear`.
    ///   - height: The vertical distance between the two sections.
    ///   - other: A builder that returns the 2D shape to use for the second section, placed at the specified height.
    ///
    /// - Returns: A lofted 3D shape connecting the two 2D sections.
    ///
    /// - Example:
    ///   ```swift
    ///   Circle(radius: 10)
    ///       .lofted(height: 20) {
    ///           Rectangle(20).aligned(at: .center)
    ///       }
    ///   ```
    ///   This creates a lofted shape from a circle at the base to a square at the top.
    ///
    /// - SeeAlso: `Loft`
    func lofted(
        shapingFunction: ShapingFunction = .linear,
        height: Double,
        @GeometryBuilder2D with other: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry3D {
        Loft(interpolation: shapingFunction) {
            Section(at: 0) { self }
            Section(at: height, shape: other)
        }
    }

    /// Creates a 3D lofted shape between this 2D shape and another one at a given offset,
    /// using the specified section transition.
    ///
    /// This is a convenience shortcut for creating a `Loft` with two sections.
    ///
    /// - Parameters:
    ///   - transition: The transition type that controls how the second section connects to the first.
    ///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
    ///   - height: The vertical distance between the two sections.
    ///   - other: A builder that returns the 2D shape to use for the second section, placed at the specified height.
    ///
    /// - Returns: A lofted 3D shape connecting the two 2D sections.
    ///
    /// - Example:
    ///   ```swift
    ///   Circle(radius: 10)
    ///       .lofted(transition: .convexHull, height: 20) {
    ///           Rectangle(20).aligned(at: .center)
    ///       }
    ///   ```
    ///
    /// - SeeAlso: `Loft`, `Loft.Transition`
    func lofted(
        transition: Loft.Transition,
        height: Double,
        @GeometryBuilder2D with other: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry3D {
        Loft {
            Section(at: 0) { self }
            Section(at: height, interpolation: transition, shape: other)
        }
    }
}
