import Foundation

/// Deprecated. Use ``Geometry`` directly.
@available(*, deprecated, renamed: "Geometry", message: "Conform to Geometry directly.")
public typealias Shape = Geometry

/// Deprecated. Use ``Geometry2D`` directly.
@available(*, deprecated, renamed: "Geometry2D", message: "Conform to Geometry2D directly.")
public protocol Shape2D: Geometry where D == D2 {
    @GeometryBuilder2D var body: any Geometry2D { get }
}

/// Deprecated. Use ``Geometry3D`` directly.
@available(*, deprecated, renamed: "Geometry3D", message: "Conform to Geometry3D directly.")
public protocol Shape3D: Geometry where D == D3 {
    @GeometryBuilder3D var body: any Geometry3D { get }
}
