public extension Loft {
    /// A result builder for composing loft sections.
    typealias SectionBuilder = ArrayBuilder<Section>

    /// A single cross-section in a lofted shape.
    ///
    /// Each section defines a 2D shape at a specific distance along the loft's path (the distance
    /// traveled along ``Loft/init(along:interpolation:pointing:toward:sections:)``'s `path`, or along the
    /// implicit straight vertical axis when no path is given). Sections are created using the
    /// `Section(at:interpolation:)` or `Section(atRelative:interpolation:)` initializers within a
    /// ``Loft`` builder.
    ///
    struct Section: Sendable {
        internal enum DistanceSpecification: Sendable {
            case absolute(Double, upperBound: Double? = nil)
            case offset(Double, upperBound: Double? = nil)
        }

        internal let distanceSpec: DistanceSpecification
        internal let transition: Transition?
        internal let geometry: @Sendable () -> any Geometry2D

        internal init(distanceSpec: DistanceSpecification, transition: Transition?, geometry: @Sendable @escaping () -> any Geometry2D) {
            self.distanceSpec = distanceSpec
            self.transition = transition
            self.geometry = geometry
        }

        internal init(distance: Double, transition: Transition?, geometry: @Sendable @escaping () -> any Geometry2D) {
            self.init(distanceSpec: .absolute(distance, upperBound: nil), transition: transition, geometry: geometry)
        }

        internal var distance: Double {
            guard case .absolute(let distance, _) = distanceSpec else {
                preconditionFailure("Section distance has not been resolved — use Section(at:) or Section(atRelative:) inside a Loft builder")
            }
            return distance
        }

        /// Expands this section into its resolved (absolute-distance) form, given the distance of the
        /// previously resolved section (used to resolve `atRelative:` offsets and to seed the next
        /// section's offset base). Range specifications expand into two sections.
        internal func resolved(lastDistance: inout Double) -> [Section] {
            switch distanceSpec {
            case .absolute(let lower, let upper):
                var result = [Section(distance: lower, transition: transition, geometry: geometry)]
                lastDistance = lower
                if let upper {
                    result.append(Section(distance: upper, transition: .interpolated(.linear), geometry: geometry))
                    lastDistance = upper
                }
                return result
            case .offset(let lower, let upper):
                let base = lastDistance
                let lowerDistance = base + lower
                var result = [Section(distance: lowerDistance, transition: transition, geometry: geometry)]
                lastDistance = lowerDistance
                if let upper {
                    let upperDistance = base + upper
                    result.append(Section(distance: upperDistance, transition: .interpolated(.linear), geometry: geometry))
                    lastDistance = upperDistance
                }
                return result
            }
        }

        /// Creates a single cross-section at the specified distance along the loft's path.
        ///
        /// - Parameters:
        ///   - distance: The distance along the path at which to place the 2D shape.
        ///   - shapingFunction: An optional shaping function that controls how the transition progresses between
        ///                      the previous section and this one. If `nil`, the `Loft`'s own shaping function is used.
        ///   - shape: A builder that returns the 2D geometry to use for this section.
        ///
        public init(
            at distance: Double,
            interpolation shapingFunction: ShapingFunction? = nil,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .absolute(distance), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
        }

        /// Creates a single cross-section at the specified distance along the loft's path, with a specified
        /// transition type.
        ///
        /// - Parameters:
        ///   - distance: The distance along the path at which to place the 2D shape.
        ///   - transition: The transition type that controls how this section connects to the previous one.
        ///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
        ///   - shape: A builder that returns the 2D geometry to use for this section.
        ///
        public init(
            at distance: Double,
            interpolation transition: Transition,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .absolute(distance), transition: transition, geometry: shape)
        }

        /// Creates two cross-sections spanning a distance range using the same 2D shape.
        ///
        /// This convenience initializer expands to a pair of sections: one at `range.lowerBound` and one at
        /// `range.upperBound`, both using the same shape. This is useful when you want a straight (unchanging)
        /// cross-section across the specified interval, for example to give a lofted shape a flat run before
        /// it starts transitioning to the next section.
        ///
        /// - Parameters:
        ///   - range: The distance range, in arc length along the loft's path, spanning both sections.
        ///   - shapingFunction: An optional shaping function that controls how the transition progresses between
        ///                      the previous section and the lower bound of this range. If `nil`, the `Loft`'s
        ///                      shaping function is used for the first section.
        ///   - shape: A builder that returns the 2D geometry to use for both sections.
        ///
        public init(
            at range: Range<Double>,
            interpolation shapingFunction: ShapingFunction? = nil,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .absolute(range.lowerBound, upperBound: range.upperBound), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
        }

        /// Creates two cross-sections spanning a distance range using the same 2D shape, with a specified
        /// transition type.
        ///
        /// - Parameters:
        ///   - range: The distance range, in arc length along the loft's path, spanning both sections.
        ///   - transition: The transition type that controls how this range connects to the previous section.
        ///                 Use `.interpolated(_:)` for shape interpolation or `.convexHull` for a convex hull connection.
        ///   - shape: A builder that returns the 2D geometry to use for both sections.
        ///
        public init(
            at range: Range<Double>,
            interpolation transition: Transition,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .absolute(range.lowerBound, upperBound: range.upperBound), transition: transition, geometry: shape)
        }

        /// Creates a single cross-section at a distance relative to the previous section.
        ///
        /// The section is placed at the distance of the preceding section plus the given offset. This is
        /// useful when building up a loft incrementally, where each section's position is defined relative
        /// to the one before it rather than as an absolute distance.
        ///
        /// - Parameters:
        ///   - offset: The distance from the previous section. Must be positive.
        ///   - shapingFunction: An optional shaping function for the transition from the previous section.
        ///                      If `nil`, the `Loft`'s own shaping function is used.
        ///   - shape: A builder that returns the 2D geometry to use for this section.
        ///
        public init(
            atRelative offset: Double,
            interpolation shapingFunction: ShapingFunction? = nil,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .offset(offset), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
        }

        /// Creates a single cross-section at a distance relative to the previous section, with a specified
        /// transition type.
        ///
        /// - Parameters:
        ///   - offset: The distance from the previous section. Must be positive.
        ///   - transition: The transition type that controls how this section connects to the previous one.
        ///   - shape: A builder that returns the 2D geometry to use for this section.
        ///
        public init(
            atRelative offset: Double,
            interpolation transition: Transition,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .offset(offset), transition: transition, geometry: shape)
        }

        /// Creates two cross-sections spanning an offset range, relative to the previous section, using the
        /// same 2D shape.
        ///
        /// This convenience initializer generates a pair of sections from a single shape: one at
        /// `previous + range.lowerBound` and one at `previous + range.upperBound`, both using the same
        /// shape. This is useful when you want a straight shape across the specified interval, defined
        /// relative to the previous section rather than at an absolute distance.
        ///
        /// - Parameters:
        ///   - range: The distance offset range relative to the previous section.
        ///   - shapingFunction: An optional shaping function that controls how the transition progresses between
        ///                      the previous section and the lower bound of this range. If `nil`, the `Loft`'s
        ///                      shaping function is used for the first section.
        ///   - shape: A builder that returns the 2D geometry to use for both sections.
        ///
        public init(
            atRelative range: Range<Double>,
            interpolation shapingFunction: ShapingFunction? = nil,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .offset(range.lowerBound, upperBound: range.upperBound), transition: shapingFunction.map { .interpolated($0) }, geometry: shape)
        }

        /// Creates two cross-sections spanning an offset range, relative to the previous section, using the
        /// same 2D shape, with a specified transition type.
        ///
        /// - Parameters:
        ///   - range: The distance offset range relative to the previous section.
        ///   - transition: The transition type that controls how this range connects to the previous section.
        ///   - shape: A builder that returns the 2D geometry to use for both sections.
        ///
        public init(
            atRelative range: Range<Double>,
            interpolation transition: Transition,
            @GeometryBuilder2D shape: @Sendable @escaping () -> any Geometry2D
        ) {
            self.init(distanceSpec: .offset(range.lowerBound, upperBound: range.upperBound), transition: transition, geometry: shape)
        }
    }
}

/// A single cross-section in a lofted shape, placed at a specific distance along the loft's path.
///
/// - SeeAlso: ``Loft/Section``
public typealias Section = Loft.Section
