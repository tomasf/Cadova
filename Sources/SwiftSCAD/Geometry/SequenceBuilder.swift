import Foundation

@resultBuilder public struct SequenceBuilder {
	public static func buildBlock(_ children: Geometry3D...) -> [Geometry3D] {
		return children
	}

	public static func buildIf(_ children: Geometry3D?...) -> [Geometry3D] {
		return children.compactMap { $0 }
	}


	public static func buildBlock(_ children: Geometry2D...) -> [Geometry2D] {
		return children
	}

	public static func buildIf(_ children: Geometry2D?...) -> [Geometry2D] {
		return children.compactMap { $0 }
	}
}
