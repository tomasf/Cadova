import Foundation

/// A type that has a measurable area.
///
/// Conforming types provide an `area` property representing the enclosed surface area.
/// Many 2D shapes in Cadova conform to this protocol, including ``Circle``, ``Rectangle``,
/// ``RegularPolygon``, and others.
///
public protocol Area {
    /// The enclosed area of the shape.
    var area: Double { get }
}

/// A type that has a measurable perimeter.
///
/// Conforming types provide a `perimeter` property representing the total length of
/// the shape's boundary. Many 2D shapes in Cadova conform to this protocol, including
/// ``Circle`` (where it represents circumference), ``Rectangle``, ``RegularPolygon``, and others.
///
public protocol Perimeter {
    /// The total length of the shape's boundary.
    var perimeter: Double { get }
}

public extension Area {
    /// Calculates the volume of a pyramid with this shape as the base.
    ///
    /// - Parameter height: The height of the pyramid from base to apex.
    /// - Returns: The volume of the pyramid.
    ///
    func pyramidVolume(height: Double) -> Double {
        return (area * height) / 3.0
    }
}
