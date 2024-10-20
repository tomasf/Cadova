import Foundation

public extension BezierPath {
    @resultBuilder struct Builder {
        public typealias Component = BezierPath<V>.Component

        public static func buildExpression(_ expression: Component) -> [Component] {
            [expression]
        }

        public static func buildBlock(_ children: [Component]...) -> [Component] {
            children.flatMap { $0 }
        }

        // If without else
        public static func buildOptional(_ children: [Component]?) -> [Component] {
            if let children {
                [.init(group: children)]
            } else {
                []
            }
        }

        // If
        public static func buildEither(first child: [Component]) -> [Component] {
            [.init(group: child)]
        }

        // Else
        public static func buildEither(second child: [Component]) -> [Component] {
            [.init(group: child)]
        }

        // Loops
        public static func buildArray(_ children: [[Component]]) -> [Component] {
            children.flatMap { $0 }
        }

        public static func buildExpression(_ void: Void) -> [Component] { [] }
        public static func buildExpression(_ never: Never) -> [Component] {}
    }
}

public extension BezierPath {
    enum BuilderPositioning {
        case relative
        case absolute
    }

    init(from: V = .zero, _ positioning: BuilderPositioning = .absolute, @Builder builder: () -> [Component]) {
        var start = from
        self.init(startPoint: from, curves: builder().flatMap {
            $0.bezierCurves(start: &start, positioning: positioning)
        })
    }
}
