import Foundation

@resultBuilder struct SequenceBuilder {
	static func buildBlock(_ children: Geometry3D...) -> [Geometry3D] {
		return children
	}

	static func buildIf(_ children: Geometry3D?...) -> [Geometry3D] {
		return children.compactMap { $0 }
	}


	static func buildBlock(_ children: Geometry2D...) -> [Geometry2D] {
		return children
	}

	static func buildIf(_ children: Geometry2D?...) -> [Geometry2D] {
		return children.compactMap { $0 }
	}
}
