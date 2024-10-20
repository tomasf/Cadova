extension BezierPath {
    public struct Component {
        private enum Contents {
            case points ([OptionalVector<V>])
            case subcomponents ([Component])
        }
        private let contents: Contents

        internal init(_ points: [OptionalVector<V>]) {
            contents = .points(points)
        }

        internal init(group: [Component]) {
            contents = .subcomponents(group)
        }

        internal func bezierCurves(start: inout V, positioning: BezierPath<V>.BuilderPositioning) -> [BezierCurve<V>] {
            switch contents {
            case .points (let points):
                let controlPoints: [V]
                switch positioning {
                case .relative:
                    controlPoints = [start] + points.map { $0.vector(with: .zero) + start }

                case .absolute:
                    controlPoints = [start] + points.map { $0.vector(with: start) }
                }

                start = controlPoints.last!
                return [BezierCurve(controlPoints: controlPoints)]

            case .subcomponents (let components):
                var localStart = start
                return components.flatMap {
                    $0.bezierCurves(start: &localStart, positioning: positioning)
                }
            }
        }
    }
}
