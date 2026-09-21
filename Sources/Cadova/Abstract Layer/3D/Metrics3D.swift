import Foundation

/// A type that has a measurable volume.
///
/// Conforming types provide a `volume` property representing the enclosed volume. Many 3D shapes
/// in Cadova conform to this protocol, including ``Box``, ``Sphere``, ``Cylinder``, ``Torus``, and
/// ``Tube``.
///
public protocol Volume {
    /// The enclosed volume of the shape.
    var volume: Double { get }
}

/// A type that has a measurable surface area.
///
/// Conforming types provide a `surfaceArea` property representing the total area of the shape's
/// boundary surface. Many 3D shapes in Cadova conform to this protocol, including ``Box``,
/// ``Sphere``, ``Cylinder``, ``Torus``, and ``Tube``.
///
public protocol SurfaceArea {
    /// The total area of the shape's boundary surface.
    var surfaceArea: Double { get }
}
