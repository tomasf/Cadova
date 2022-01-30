import Foundation

@resultBuilder public struct SequenceBuilder {
}

extension SequenceBuilder {
	public static func buildExpression(_ expression: Geometry3D) -> [Geometry3D] {
		[expression]
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

	public static func buildOptional(_ children: [Geometry3D]?) -> [Geometry3D] {
		children ?? []
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
}

extension SequenceBuilder {
	public static func buildExpression(_ expression: Geometry2D) -> [Geometry2D] {
		[expression]
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

	public static func buildOptional(_ children: [Geometry2D]?) -> [Geometry2D] {
		children ?? []
	}

	public static func buildEither(first child: Geometry2D) -> [Geometry2D] {
		[child]
	}

	public static func buildEither(second child: Geometry2D) -> [Geometry2D] {
		[child]
	}

	public static func buildArray(_ children: [[Geometry2D]]) -> [Geometry2D] {
		children.flatMap { $0 }
	}
}
