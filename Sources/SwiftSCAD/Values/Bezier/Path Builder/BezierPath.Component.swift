extension BezierPath {
    public struct Component {
        private enum Contents {
            case points ([OptionalVector<V>])
            case subcomponents ([Component], positioning: BezierPath.Positioning?)
        }
        private let contents: Contents

        internal init(_ points: [OptionalVector<V>]) {
            contents = .points(points)
        }

        internal init(group: [Component], positioning: BezierPath.Positioning? = nil) {
            contents = .subcomponents(group, positioning: positioning)
        }

        internal func bezierCurves(start: inout V, positioning: BezierPath<V>.Positioning) -> [BezierCurve<V>] {
            switch contents {
            case .points (let points):
                let addition = positioning == .absolute ? .zero : start
                let controlPoints = [start] + points.map { $0.vector(with: start) + addition }
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
