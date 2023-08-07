import Foundation

/// An `Arc` represents a segment of a circle in two-dimensional space.
/// It can be defined by a range of angles and either a radius or a diameter.
///
/// # Example
/// ```swift
/// let arcWithRadius = Arc(range: 0°..<90°, radius: 5)
/// let arcWithDiameter = Arc(range: 0°..<90°, diameter: 10)
/// ```
public struct Arc: ContainerGeometry2D {
    let range: Range<Angle>
    let radius: Double

    /// Creates a new `Arc` instance with the specified range of angles and radius.
    ///
    /// - Parameter range: The range of angles to include in the arc.
    /// - Parameter radius: The radius of the arc.
    public init(range: Range<Angle>, radius: Double) {
        self.range = range
        self.radius = radius
    }

    /// Creates a new `Arc` instance with the specified range of angles and diameter.
    ///
    /// - Parameter range: The range of angles to include in the arc.
    /// - Parameter diameter: The diameter of the arc.
    public init(range: Range<Angle>, diameter: Double) {
        self.init(range: range, radius: diameter / 2)
    }

    func geometry(in environment: Environment) -> Geometry2D {
        let magnitude = range.upperBound - range.lowerBound
        let fraction = magnitude / 360°

        let circleFacets: Double

        switch environment.facets {
        case .fixed (let perRev):
            circleFacets = Double(perRev)

        case .dynamic (let minAngle, let minSize):
            let facetsFromAngle = 360° / minAngle
            let circumference = radius * 2.0 * .pi
            let facetsFromSize = circumference / minSize
            circleFacets = min(facetsFromAngle, facetsFromSize)
        }

        let facetCount = max(Int(ceil(circleFacets * fraction)), 2)
        let facetAngle = magnitude / Double(facetCount)

        let outerPoints = (0...facetCount).map { i -> Vector2D in
            let angle = range.lowerBound + facetAngle * Double(i)
            return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        let allPoints = [Vector2D.zero] + outerPoints + [Vector2D.zero]

        return Polygon(allPoints)
    }
}
