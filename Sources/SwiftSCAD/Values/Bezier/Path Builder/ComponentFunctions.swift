import Foundation

public func line<V: Vector>(_ point: V) -> BezierPath<V>.Component {
    .init([.init(point)])
}

public func curve<V: Vector>(_ controlPoints: [V]) -> BezierPath<V>.Component {
    .init(controlPoints.map(OptionalVector.init))
}

// MARK: - Groups

public func group<V: Vector>(@BezierPath<V>.Builder builder: () -> [BezierPath<V>.Component]) -> BezierPath<V>.Component {
    .init(group: builder())
}


// MARK: - 2D

public func line(x: Double? = nil, y: Double? = nil) -> BezierPath2D.Component {
    .init([.init(x, y)])
}

public func curve(
    controlX x1: Double, controlY y1: Double,
    endX endX: Double,   endY endY: Double
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(endX, endY)])
}

public func curve(
    controlX x1: Double, controlY y1: Double,
    controlX x2: Double, controlY y2: Double,
    endX endX: Double,   endY endY: Double
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(x2, y2), .init(endX, endY)])
}


// MARK: - 3D

public func line(x: Double? = nil, y: Double? = nil, z: Double? = nil) -> BezierPath3D.Component {
    .init([.init(x, y, z)])
}

public func curve(
    controlX x1: Double, controlY y1: Double, controlZ z1: Double,
    endX endX: Double,   endY endY: Double,   endZ endZ: Double
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(endX, endY, endZ)])
}

public func curve(
    controlX x1: Double, controlY y1: Double, controlZ z1: Double,
    controlX x2: Double, controlY y2: Double, controlZ z2: Double,
    endX: Double,        endY: Double,        endZ: Double
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(x2, y2, z2), .init(endX, endY, endZ)])
}
