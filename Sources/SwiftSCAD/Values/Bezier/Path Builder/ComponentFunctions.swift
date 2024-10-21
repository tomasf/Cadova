import Foundation

public func line<V: Vector>(_ point: V) -> BezierPath<V>.Component {
    .init([.init(point)])
}

public func curve<V: Vector>(_ controlPoints: [V]) -> BezierPath<V>.Component {
    .init(controlPoints.map(PathBuilderVector<V>.init))
}

// MARK: - 2D

public func line(
    x: any PathBuilderValue = .unchanged,
    y: any PathBuilderValue = .unchanged
) -> BezierPath2D.Component {
    .init([.init(x, y)])
}

public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(endX, endY)])
}

public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue,
    controlX x2: any PathBuilderValue, controlY y2: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(x2, y2), .init(endX, endY)])
}


// MARK: - 3D

public func line(
    x: any PathBuilderValue = .unchanged,
    y: any PathBuilderValue = .unchanged,
    z: any PathBuilderValue = .unchanged
) -> BezierPath3D.Component {
    .init([.init(x, y, z)])
}

public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue, controlZ z1: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue, endZ: any PathBuilderValue
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(endX, endY, endZ)])
}

public func curve(
    controlX x1: any PathBuilderValue, controlY y1: any PathBuilderValue, controlZ z1: any PathBuilderValue,
    controlX x2: any PathBuilderValue, controlY y2: any PathBuilderValue, controlZ z2: any PathBuilderValue,
    endX: any PathBuilderValue, endY: any PathBuilderValue, endZ: any PathBuilderValue
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(x2, y2, z2), .init(endX, endY, endZ)])
}
