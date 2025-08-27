import Foundation

public extension BezierPath {
    typealias Builder = ArrayBuilder<BezierPath<V>.Component>

    init(from: V = .zero, mode defaultMode: PathBuilderPositioning = .absolute, @Builder builder: () -> [Component]) {
        var path = BezierPath(startPoint: from)
        for component in builder() {
            path = component.appendAction(path, defaultMode)
        }
        self = path
    }

    struct Component {
        internal let appendAction: (BezierPath, PathBuilderPositioning) -> BezierPath

        internal init(appendAction: @escaping (BezierPath, PathBuilderPositioning) -> BezierPath) {
            self.appendAction = appendAction
        }

        internal init(continuousDistance: Double? = nil, _ points: [PathBuilderVector<V>]) {
            self.init { path, defaultMode in
                let start = path.endPoint
                var controlPoints: [V] = []

                if let continuousDistance {
                    guard let direction = path.endDirection else {
                        preconditionFailure("Adding a continuous segment requires a previous segment to match")
                    }
                    controlPoints.append(start + direction.unitVector * continuousDistance)
                }

                controlPoints += points.map {
                    $0.value(relativeTo: start, defaultMode: defaultMode)
                }

                return path.addingCurve(controlPoints)
            }
        }

        internal func withDefaultMode(_ mode: PathBuilderPositioning) -> Self {
            let oldAction = self.appendAction
            return Self { path, _ in
                oldAction(path, mode)
            }
        }

        public var relative: Component { withDefaultMode(.relative) }
        public var absolute: Component { withDefaultMode(.absolute) }
    }
}

public enum PathBuilderPositioning: Sendable {
    case absolute
    case relative
}
