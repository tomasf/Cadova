import Foundation

/// Criteria for selecting edges in a mesh.
///
/// `EdgeCriteria` provides a declarative way to describe which edges to select
/// without requiring direct access to the mesh topology. Criteria can be composed
/// and reused across multiple operations.
///
/// All criteria implicitly filter for sharp edges (edges where faces meet at an angle).
/// This excludes flat internal mesh edges that are artifacts of triangulation.
/// Use ``sharp(threshold:)`` to adjust the sharpness threshold.
///
/// ```swift
/// // Simple usage with cuttingEdgeProfile
/// box.cuttingEdgeProfile(.fillet(radius: 2), along: .perpendicular(to: .z))
///
/// // Reusable criteria
/// let verticalEdges: EdgeCriteria = .aligned(with: .z)
/// box.cuttingEdgeProfile(.chamfer(depth: 1), along: verticalEdges)
///
/// // Custom sharpness threshold
/// box.cuttingEdgeProfile(.fillet(radius: 1), along: .sharp(threshold: 80°))
/// ```
///
public struct EdgeCriteria: Sendable {
    /// The default sharpness threshold applied to all criteria.
    ///
    /// Edges with dihedral angles below this threshold are considered "sharp"
    /// and will be selected. The default of 170° catches nearly all meaningful
    /// edges while excluding flat internal mesh edges.
    ///
    public static let defaultSharpnessThreshold: Angle = 170°

    internal let filters: [Filter]
    internal let hasExplicitSharpness: Bool

    internal init(filters: [Filter], hasExplicitSharpness: Bool = false) {
        self.filters = filters
        self.hasExplicitSharpness = hasExplicitSharpness
    }

    internal indirect enum Filter: Sendable {
        case sharp(threshold: Angle)
        case dihedralAngle(ClosedRange<Angle>)
        case withinBox(BoundingBox3D)
        case nearPoint(Vector3D, distance: Double)
        case nearAxis(Axis3D, distance: Double, origin: Vector3D)
        case alignedWithDirection(Direction3D, tolerance: Angle)
        case perpendicularToDirection(Direction3D, tolerance: Angle)
        case inPlane(Plane, tolerance: Double)
        case lengthRange(ClosedRange<Double>)
        case minLength(Double)
        case maxLength(Double)
        case union(EdgeCriteria)
        case intersection(EdgeCriteria)
        case subtracting(EdgeCriteria)
    }

    private func adding(_ filter: Filter) -> EdgeCriteria {
        EdgeCriteria(filters: filters + [filter], hasExplicitSharpness: hasExplicitSharpness)
    }

    private func withExplicitSharpness(_ filter: Filter) -> EdgeCriteria {
        EdgeCriteria(filters: filters + [filter], hasExplicitSharpness: true)
    }
}

// MARK: - Static Constructors

public extension EdgeCriteria {
    /// Criteria for sharp edges based on dihedral angle.
    ///
    /// Use this to set a custom sharpness threshold. If not specified,
    /// criteria use ``defaultSharpnessThreshold`` (170°) automatically.
    ///
    /// - Parameter threshold: The maximum dihedral angle for an edge to be considered sharp.
    ///   Default is 100° (more selective than the implicit default).
    ///
    static func sharp(threshold: Angle = 100°) -> EdgeCriteria {
        EdgeCriteria(filters: [.sharp(threshold: threshold)], hasExplicitSharpness: true)
    }

    /// Criteria for edges within a specific dihedral angle range.
    ///
    /// This is considered an explicit sharpness specification and will not
    /// have the default sharpness threshold applied.
    ///
    static func withDihedralAngle(in range: ClosedRange<Angle>) -> EdgeCriteria {
        EdgeCriteria(filters: [.dihedralAngle(range)], hasExplicitSharpness: true)
    }

    /// Criteria for edges within a bounding box.
    static func within(_ box: BoundingBox3D) -> EdgeCriteria {
        EdgeCriteria(filters: [.withinBox(box)])
    }

    /// Criteria for edges within specified coordinate ranges.
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis.
    ///   - y: Optional range along the y-axis.
    ///   - z: Optional range along the z-axis.
    ///
    static func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> EdgeCriteria {
        let largeValue = 1e10
        let box = BoundingBox3D(
            minimum: Vector3D(
                x: x?.min ?? -largeValue,
                y: y?.min ?? -largeValue,
                z: z?.min ?? -largeValue
            ),
            maximum: Vector3D(
                x: x?.max ?? largeValue,
                y: y?.max ?? largeValue,
                z: z?.max ?? largeValue
            )
        )
        return EdgeCriteria(filters: [.withinBox(box)])
    }

    /// Criteria for edges near a point.
    static func nearPoint(_ point: Vector3D, distance: Double) -> EdgeCriteria {
        EdgeCriteria(filters: [.nearPoint(point, distance: distance)])
    }

    /// Criteria for edges near an axis.
    static func nearAxis(_ axis: Axis3D, distance: Double, origin: Vector3D = .zero) -> EdgeCriteria {
        EdgeCriteria(filters: [.nearAxis(axis, distance: distance, origin: origin)])
    }

    /// Criteria for edges aligned with a direction.
    ///
    /// - Parameters:
    ///   - direction: The direction to compare against.
    ///   - tolerance: The maximum angle deviation. Default is 15°.
    ///
    static func aligned(with direction: Direction3D, tolerance: Angle = 15°) -> EdgeCriteria {
        EdgeCriteria(filters: [.alignedWithDirection(direction, tolerance: tolerance)])
    }

    /// Criteria for edges aligned with an axis.
    static func aligned(with axis: Axis3D, tolerance: Angle = 15°) -> EdgeCriteria {
        aligned(with: axis.direction(.positive), tolerance: tolerance)
    }

    /// Criteria for edges perpendicular to a direction.
    ///
    /// - Parameters:
    ///   - direction: The direction to compare against.
    ///   - tolerance: The maximum angle deviation from perpendicular. Default is 15°.
    ///
    static func perpendicular(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeCriteria {
        EdgeCriteria(filters: [.perpendicularToDirection(direction, tolerance: tolerance)])
    }

    /// Criteria for edges perpendicular to an axis.
    static func perpendicular(to axis: Axis3D, tolerance: Angle = 15°) -> EdgeCriteria {
        perpendicular(to: axis.direction(.positive), tolerance: tolerance)
    }

    /// Criteria for edges lying in a plane.
    static func `in`(plane: Plane, tolerance: Double = 0.01) -> EdgeCriteria {
        EdgeCriteria(filters: [.inPlane(plane, tolerance: tolerance)])
    }

    /// Criteria for edges within a length range.
    static func withLength(in range: ClosedRange<Double>) -> EdgeCriteria {
        EdgeCriteria(filters: [.lengthRange(range)])
    }

    /// Criteria for edges with at least the specified minimum length.
    static func withMinimumLength(_ minLength: Double) -> EdgeCriteria {
        EdgeCriteria(filters: [.minLength(minLength)])
    }

    /// Criteria for edges with at most the specified maximum length.
    static func withMaximumLength(_ maxLength: Double) -> EdgeCriteria {
        EdgeCriteria(filters: [.maxLength(maxLength)])
    }
}

// MARK: - Chainable Methods

public extension EdgeCriteria {
    /// Adds a sharpness filter to the criteria.
    ///
    /// This overrides the default sharpness threshold.
    ///
    func sharp(threshold: Angle = 100°) -> EdgeCriteria {
        withExplicitSharpness(.sharp(threshold: threshold))
    }

    /// Adds a dihedral angle range filter.
    ///
    /// This is considered an explicit sharpness specification.
    ///
    func withDihedralAngle(in range: ClosedRange<Angle>) -> EdgeCriteria {
        withExplicitSharpness(.dihedralAngle(range))
    }

    /// Adds a bounding box filter.
    func within(_ box: BoundingBox3D) -> EdgeCriteria {
        adding(.withinBox(box))
    }

    /// Adds coordinate range filters.
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> EdgeCriteria {
        let largeValue = 1e10
        let box = BoundingBox3D(
            minimum: Vector3D(
                x: x?.min ?? -largeValue,
                y: y?.min ?? -largeValue,
                z: z?.min ?? -largeValue
            ),
            maximum: Vector3D(
                x: x?.max ?? largeValue,
                y: y?.max ?? largeValue,
                z: z?.max ?? largeValue
            )
        )
        return adding(.withinBox(box))
    }

    /// Adds a near-point filter.
    func nearPoint(_ point: Vector3D, distance: Double) -> EdgeCriteria {
        adding(.nearPoint(point, distance: distance))
    }

    /// Adds a near-axis filter.
    func nearAxis(_ axis: Axis3D, distance: Double, origin: Vector3D = .zero) -> EdgeCriteria {
        adding(.nearAxis(axis, distance: distance, origin: origin))
    }

    /// Adds a direction alignment filter.
    func aligned(with direction: Direction3D, tolerance: Angle = 15°) -> EdgeCriteria {
        adding(.alignedWithDirection(direction, tolerance: tolerance))
    }

    /// Adds an axis alignment filter.
    func aligned(with axis: Axis3D, tolerance: Angle = 15°) -> EdgeCriteria {
        aligned(with: axis.direction(.positive), tolerance: tolerance)
    }

    /// Adds a perpendicular-to-direction filter.
    func perpendicular(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeCriteria {
        adding(.perpendicularToDirection(direction, tolerance: tolerance))
    }

    /// Adds a perpendicular-to-axis filter.
    func perpendicular(to axis: Axis3D, tolerance: Angle = 15°) -> EdgeCriteria {
        perpendicular(to: axis.direction(.positive), tolerance: tolerance)
    }

    /// Adds a plane containment filter.
    func `in`(plane: Plane, tolerance: Double = 0.01) -> EdgeCriteria {
        adding(.inPlane(plane, tolerance: tolerance))
    }

    /// Adds a length range filter.
    func withLength(in range: ClosedRange<Double>) -> EdgeCriteria {
        adding(.lengthRange(range))
    }

    /// Adds a minimum length filter.
    func withMinimumLength(_ minLength: Double) -> EdgeCriteria {
        adding(.minLength(minLength))
    }

    /// Adds a maximum length filter.
    func withMaximumLength(_ maxLength: Double) -> EdgeCriteria {
        adding(.maxLength(maxLength))
    }
}

// MARK: - Set Operations

public extension EdgeCriteria {
    /// Combines this criteria with another using union (OR).
    ///
    /// Edges matching either criteria will be selected.
    ///
    func union(_ other: EdgeCriteria) -> EdgeCriteria {
        adding(.union(other))
    }

    /// Combines this criteria with another using intersection (AND).
    ///
    /// Only edges matching both criteria will be selected.
    ///
    func intersection(_ other: EdgeCriteria) -> EdgeCriteria {
        adding(.intersection(other))
    }

    /// Subtracts another criteria from this one.
    ///
    /// Edges matching this criteria but not the other will be selected.
    ///
    func subtracting(_ other: EdgeCriteria) -> EdgeCriteria {
        adding(.subtracting(other))
    }

    /// Combines two criteria using union (OR).
    static func || (lhs: EdgeCriteria, rhs: EdgeCriteria) -> EdgeCriteria {
        lhs.union(rhs)
    }

    /// Combines two criteria using intersection (AND).
    static func && (lhs: EdgeCriteria, rhs: EdgeCriteria) -> EdgeCriteria {
        lhs.intersection(rhs)
    }
}

// MARK: - Application

internal extension EdgeCriteria {
    /// Applies this criteria to an edge selection, returning a filtered selection.
    ///
    /// If no explicit sharpness filter was specified, applies the default sharpness
    /// threshold to exclude flat internal mesh edges.
    ///
    func apply(to selection: EdgeSelection) -> EdgeSelection {
        var current = selection

        // Apply default sharpness filter if none was explicitly specified
        if !hasExplicitSharpness {
            current = current.sharp(threshold: Self.defaultSharpnessThreshold)
        }

        for filter in filters {
            current = applyFilter(filter, to: current)
        }

        return current
    }

    private func applyFilter(_ filter: Filter, to selection: EdgeSelection) -> EdgeSelection {
        switch filter {
        case .sharp(let threshold):
            return selection.sharp(threshold: threshold)

        case .dihedralAngle(let range):
            return selection.withDihedralAngle(in: range)

        case .withinBox(let box):
            return selection.within(box)

        case .nearPoint(let point, let distance):
            return selection.nearPoint(point, distance: distance)

        case .nearAxis(let axis, let distance, let origin):
            return selection.nearAxis(axis, distance: distance, origin: origin)

        case .alignedWithDirection(let direction, let tolerance):
            return selection.aligned(with: direction, tolerance: tolerance)

        case .perpendicularToDirection(let direction, let tolerance):
            return selection.perpendicular(to: direction, tolerance: tolerance)

        case .inPlane(let plane, let tolerance):
            return selection.in(plane: plane, tolerance: tolerance)

        case .lengthRange(let range):
            return selection.withLength(in: range)

        case .minLength(let minLength):
            return selection.withMinimumLength(minLength)

        case .maxLength(let maxLength):
            return selection.withMaximumLength(maxLength)

        case .union(let other):
            let otherSelection = other.apply(to: EdgeSelection(selection.topology))
            return selection.union(otherSelection)

        case .intersection(let other):
            let otherSelection = other.apply(to: EdgeSelection(selection.topology))
            return selection.intersection(otherSelection)

        case .subtracting(let other):
            let otherSelection = other.apply(to: EdgeSelection(selection.topology))
            return selection.subtracting(otherSelection)
        }
    }
}
