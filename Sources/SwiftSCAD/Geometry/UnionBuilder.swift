import Foundation

@resultBuilder public struct UnionBuilder {
}

extension UnionBuilder {
	public static func buildExpression(_ geometry: Geometry2D) -> [Geometry2D] {
		[geometry]
	}

	public static func buildExpression<S>(_ geometry: S) -> [Geometry2D] where S: Sequence, S.Element: Geometry2D {
		Array(geometry)
	}

	public static func buildExpression(_ void: Void) -> [Geometry2D] {
		[]
	}

	public static func buildBlock(_ children: [Geometry2D]...) -> [Geometry2D] {
		children.flatMap { $0 }
	}

	public static func buildOptional(_ child: [Geometry2D]?) -> [Geometry2D] {
		child ?? []
	}

	public static func buildEither(first child: [Geometry2D]) -> [Geometry2D] {
		child
	}

	public static func buildEither(second child: [Geometry2D]) -> [Geometry2D] {
		child
	}

	public static func buildArray(_ children: [[Geometry2D]]) -> [Geometry2D] {
		children.flatMap { $0 }
	}

	public static func buildFinalResult(_ children: [Geometry2D]) -> Geometry2D {
		if children.isEmpty {
			return Empty()
		} else if children.count > 1 {
			return Union2D(children: children)
		} else {
			return children[0]
		}
	}
}

extension UnionBuilder {
	public static func buildExpression(_ geometry: Geometry3D) -> [Geometry3D] {
		[geometry]
	}

	public static func buildExpression<S>(_ geometry: S) -> [Geometry3D] where S: Sequence, S.Element: Geometry3D {
		Array(geometry)
	}

	public static func buildExpression(_ void: Void) -> [Geometry3D] {
		[]
	}

	public static func buildBlock(_ children: [Geometry3D]...) -> [Geometry3D] {
		children.flatMap { $0 }
	}

	public static func buildOptional(_ child: [Geometry3D]?) -> [Geometry3D] {
		child ?? []
	}

	public static func buildEither(first child: [Geometry3D]) -> [Geometry3D] {
		child
	}

	public static func buildEither(second child: [Geometry3D]) -> [Geometry3D] {
		child
	}

	public static func buildArray(_ children: [[Geometry3D]]) -> [Geometry3D] {
		children.flatMap { $0 }
	}

	public static func buildFinalResult(_ children: [Geometry3D]) -> Geometry3D {
		if children.isEmpty {
			return Empty()
		} else if children.count > 1 {
			return Union3D(children: children)
		} else {
			return children[0]
		}
	}
}
