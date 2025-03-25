import Foundation

public extension BezierPath {
    typealias Builder = ArrayBuilder<BezierPath<V>.Component>

    init(from: V = .zero, mode defaultMode: PathBuilderPositioning = .absolute, @Builder builder: () -> [Component]) {
        var start = from
        var direction: V? = nil
        self.init(startPoint: from, curves: builder().map {
            $0.bezierCurve(start: &start, direction: &direction, defaultMode: defaultMode)
        })
    }

    struct Component {
        private let continuousDistance: Double?
        private let points: [PathBuilderVector<V>]

        internal init(continuousDistance: Double? = nil, _ points: [PathBuilderVector<V>]) {
            self.continuousDistance = continuousDistance
            self.points = points
        }

        internal func bezierCurve(start: inout V, direction: inout V?, defaultMode: PathBuilderPositioning) -> Curve {
            var controlPoints = [start]

            if let continuousDistance {
                guard let direction else {
                    preconditionFailure("Adding a continuous segment requires a previous segment to match")
                }
                controlPoints.append(start + direction * continuousDistance)
            }

            controlPoints += points.map {
                $0.value(relativeTo: start, defaultMode: defaultMode)
            }
            start = controlPoints.last!
            let curve = Curve(controlPoints: controlPoints)
            direction = curve.endDirection
            return curve
        }

        internal func withDefaultMode(_ mode: PathBuilderPositioning) -> Self {
            .init(points.map { $0.withDefaultMode(mode) })
        }

        public var relative: Component { withDefaultMode(.relative) }
        public var absolute: Component { withDefaultMode(.absolute) }
    }
}

public enum PathBuilderPositioning: Sendable {
    case absolute
    case relative
}
