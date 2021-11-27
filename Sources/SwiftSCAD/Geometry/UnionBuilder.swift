import Foundation

@resultBuilder public struct UnionBuilder {
	public static func buildBlock(_ children: Geometry3D...) -> Geometry3D {
		if children.isEmpty {
			return Empty()
		} else if children.count > 1 {
			return Union3D(children: children)
		} else {
			return children[0]
		}
	}

	public static func buildOptional(_ child: Geometry3D?) -> Geometry3D {
		child ?? Empty()
	}

	public static func buildEither(first child: Geometry3D) -> Geometry3D {
		child
	}

	public static func buildEither(second child: Geometry3D) -> Geometry3D {
		child
	}

	public static func buildArray(_ children: [Geometry3D]) -> Geometry3D {
		Union3D(children: children)
	}


	public static func buildBlock(_ children: Geometry2D...) -> Geometry2D {
		if children.isEmpty {
			return Empty()
		} else if children.count > 1 {
			return Union2D(children: children)
		} else {
			return children[0]
		}
	}

	public static func buildOptional(_ child: Geometry2D?) -> Geometry2D {
		child ?? Empty()
	}

	public static func buildEither(first child: Geometry2D) -> Geometry2D {
		child
	}

	public static func buildEither(second child: Geometry2D) -> Geometry2D {
		child
	}

	public static func buildArray(_ children: [Geometry2D]) -> Geometry2D {
		Union2D(children: children)
	}
}
