import Foundation

/// An `Arc` represents a circular sector in two-dimensional space.
/// It can be defined by a range of angles and either a radius or a diameter.
///
/// # Example
/// ```swift
/// let arcWithRadius = Arc(range: 0°..<90°, radius: 5)
/// let arcWithDiameter = Arc(range: 0°..<90°, diameter: 10)
/// ```
public struct Arc: Shape2D {
    public let range: Range<Angle>
    public let radius: Double

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

    @Environment(\.segmentation) private var segmentation

    public var body: any Geometry2D {
        Polygon([.zero] + arcPoints(segmentation: segmentation))
    }

    private func arcPoints(segmentation: EnvironmentValues.Segmentation) -> [Vector2D] {
        let segmentCount = segmentation.segmentCount(arcRadius: radius, angle: range.length)

        return (0...segmentCount).map { i -> Vector2D in
            let angle = range.lowerBound + (Double(i) / Double(segmentCount)) * range.length
            return Vector2D(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }
}

extension Arc: Area {
    public var angularDistance: Angle { range.length }
    public var area: Double { radius * radius * .pi * (angularDistance / 360°) }
}
