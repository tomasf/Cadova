extension BezierPath {
    public struct Component {
        private enum Contents {
            case points ([V])
            case subcomponents ([Component], positioning: BezierPath.Positioning?)
        }
        private let contents: Contents

        internal init(_ points: [V]) {
            contents = .points(points)
        }

        internal init(group: [Component], positioning: BezierPath.Positioning? = nil) {
            contents = .subcomponents(group, positioning: positioning)
        }

        internal func bezierCurves(start: inout V, positioning: BezierPath<V>.Positioning) -> [BezierCurve<V>] {
            switch contents {
            case .points (let points):
                let addition = positioning == .absolute ? .zero : start
                let controlPoints = [start] + points.map { $0 + addition }
                start = controlPoints.last!
                return [BezierCurve(controlPoints: controlPoints)]

            case .subcomponents (let components, let override):
                if let override {
                    return components.flatMap {
                        $0.bezierCurves(start: &start, positioning: override)
                    }
                } else {
                    var localStart = start
                    return components.flatMap {
                        $0.bezierCurves(start: &localStart, positioning: positioning)
                    }
                }
            }
        }
    }
}

public func line<V: Vector>(_ point: V) -> BezierPath<V>.Component {
    .init([point])
}

public func curve<V: Vector>(_ controlPoints: [V]) -> BezierPath<V>.Component {
    .init(controlPoints)
}

// MARK: - Groups

public func group<V: Vector>(@BezierPath<V>.Builder builder: () -> [BezierPath<V>.Component]) -> BezierPath<V>.Component {
    .init(group: builder(), positioning: nil)
}

public func relative<V: Vector>(@BezierPath<V>.Builder builder: () -> [BezierPath<V>.Component]) -> BezierPath<V>.Component {
    .init(group: builder(), positioning: .relative)
}

public func absolute<V: Vector>(@BezierPath<V>.Builder builder: () -> [BezierPath<V>.Component]) -> BezierPath<V>.Component {
    .init(group: builder(), positioning: .absolute)
}


// MARK: - 2D

public func line(x: Double = 0, y: Double = 0) -> BezierPath2D.Component {
    .init([.init(x, y)])
}

public func curve(
    x x1: Double,   y y1: Double,
    x endX: Double, y endY: Double
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(endX, endY)])
}

public func curve(
    x x1: Double,   y y1: Double,
    x x2: Double,   y y2: Double,
    x endX: Double, y endY: Double
) -> BezierPath2D.Component {
    .init([.init(x1, y1), .init(x2, y2), .init(endX, endY)])
}


// MARK: - 3D

public func line(x: Double = 0, y: Double = 0, z: Double = 0) -> BezierPath3D.Component {
    .init([.init(x, y, z)])
}

public func curve(
    x x1: Double,   y y1: Double,   z z1: Double,
    x endX: Double, y endY: Double, z endZ: Double
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(endX, endY, endZ)])
}

public func curve(
    x x1: Double,   y y1: Double,   z z1: Double,
    x x2: Double,   y y2: Double,   z z2: Double,
    x endX: Double, y endY: Double, z endZ: Double
) -> BezierPath3D.Component {
    .init([.init(x1, y1, z1), .init(x2, y2, z2), .init(endX, endY, endZ)])
}
