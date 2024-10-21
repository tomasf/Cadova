import Foundation

public extension BezierPath {
    typealias Builder = ArrayBuilder<BezierPath<V>.Component>

    init(from: V = .zero, mode defaultMode: PathBuilderPositioning = .absolute, @Builder builder: () -> [Component]) {
        var start = from
        self.init(startPoint: from, curves: builder().flatMap {
            $0.bezierCurves(start: &start, defaultMode: defaultMode)
        })
    }

    struct Component {
        private let points: [PathBuilderVector<V>]

        internal init(_ points: [PathBuilderVector<V>]) {
            self.points = points
        }

        internal func bezierCurves(start: inout V, defaultMode: PathBuilderPositioning) -> [Curve] {
            let controlPoints = [start] + points.map {
                $0.value(relativeTo: start, defaultMode: defaultMode)
            }
            start = controlPoints.last!
            return [Curve(controlPoints: controlPoints)]
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
