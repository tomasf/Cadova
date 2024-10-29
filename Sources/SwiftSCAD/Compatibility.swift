import Foundation

// RoundedRectangle backwards compatibility

@available(*, deprecated, message: "Use .roundingRectangleCorners instead")
public func RoundedRectangle(_ size: Vector2D, style: RoundedCornerStyle = .circular, cornerRadius: Double) -> any Geometry2D {
    Rectangle(size)
        .roundingRectangleCorners(.all, radius: cornerRadius, style: style)
}

@available(*, deprecated, message: "Use .roundingRectangleCorners instead")
public func RoundedRectangle(
    _ size: Vector2D,
    style: RoundedCornerStyle = .circular,
    cornerRadii a: Double,
    _ b: Double,
    _ c: Double,
    _ d: Double
) -> any Geometry2D {
    Rectangle(size)
        .roundingRectangleCorners(.bottomLeft, radius: a, style: style)
        .roundingRectangleCorners(.bottomRight, radius: b, style: style)
        .roundingRectangleCorners(.topRight, radius: c, style: style)
        .roundingRectangleCorners(.topLeft, radius: d, style: style)
}

@available(*, deprecated, message: "Use .roundingRectangleCorners instead")
public func RoundedRectangle(
    _ size: Vector2D,
    style: RoundedCornerStyle = .circular,
    minXminY: Double = 0,
    maxXminY: Double = 0,
    maxXmaxY: Double = 0,
    minXmaxY: Double = 0
) -> any Geometry2D {
    Rectangle(size)
        .roundingRectangleCorners(.bottomLeft, radius: minXminY, style: style)
        .roundingRectangleCorners(.bottomRight, radius: maxXminY, style: style)
        .roundingRectangleCorners(.topRight, radius: maxXmaxY, style: style)
        .roundingRectangleCorners(.topLeft, radius: minXmaxY, style: style)
}


// RoundedBox backwards compatibility

@available(*, deprecated, message: "Use .roundingBoxCorners instead")
public func RoundedBox(
    _ size: Vector3D,
    axis: Axis3D,
    style: RoundedCornerStyle = .circular,
    cornerRadius: Double
) -> any Geometry3D {
    Box(size)
        .roundingBoxCorners(.all, axis: axis, radius: cornerRadius, style: style)
}

@available(*, deprecated, message: "Use .roundingBoxCorners instead")
public func RoundedBox(
    _ size: Vector3D,
    axis: Axis3D,
    style: RoundedCornerStyle = .circular,
    cornerRadii a: Double,
    _ b: Double,
    _ c: Double,
    _ d: Double
) -> any Geometry3D {
    let translatedRadii: RectangleCornerRadii = switch axis {
    case .x:
        RectangleCornerRadii(c, b, a, d)
    case .y:
        RectangleCornerRadii(d, c, b, a)
    case .z:
        RectangleCornerRadii(a, b, c, d)
    }

    return Box(size)
        .roundingBoxCorners(axis: axis, translatedRadii, style: style)
}

@available(*, deprecated, message: "Use .roundingBoxCorners instead")
public func RoundedBox(_ size: Vector3D, cornerRadius radius: Double) -> any Geometry3D {
    Box(size)
        .roundingBoxCorners(radius: radius)
}

@available(*, deprecated, message: "Use readEnvironment instead")
public func EnvironmentReader(@GeometryBuilder2D body: @escaping (Environment) -> any Geometry2D) -> any Geometry2D {
    readEnvironment(body)
}

@available(*, deprecated, message: "Use readEnvironment instead")
public func EnvironmentReader(@GeometryBuilder3D body: @escaping (Environment) -> any Geometry3D) -> any Geometry3D {
    readEnvironment(body)
}

public typealias UnionBuilder2D = GeometryBuilder2D
public typealias UnionBuilder3D = GeometryBuilder3D

@available(*, deprecated, message: "Use lowercase union instead")
public func Union(@GeometryBuilder2D _ body: () -> any Geometry2D) -> any Geometry2D {
    union(body)
}

@available(*, deprecated, message: "Use lowercase union instead")
public func Union(@GeometryBuilder3D _ body: () -> any Geometry3D) -> any Geometry3D {
    union(body)
}
