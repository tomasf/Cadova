import Foundation

struct Union3D: Geometry3D {
	let children: [Geometry3D]

	init(children: [Geometry3D]) {
		self.children = children
	}

	func scadString(environment: Environment) -> String {
		SCADCall(name: "union", body: GeometrySequence(children: children))
			.scadString(environment: environment)
	}
}

public func Union(@UnionBuilder _ body: () -> Geometry3D) -> Geometry3D {
	body()
}

public func Union(children: [Geometry3D]) -> Geometry3D {
	Union3D(children: children)
}

public extension Geometry3D {
	func adding(@SequenceBuilder _ bodies: () -> [Geometry3D]) -> Geometry3D {
		Union3D(children: [self] + bodies())
	}
}

struct Union2D: Geometry2D {
	let children: [Geometry2D]

	init(children: [Geometry2D]) {
		self.children = children
	}

	func scadString(environment: Environment) -> String {
		SCADCall(name: "union", body: GeometrySequence(children: children))
			.scadString(environment: environment)
	}
}

public func Union(@UnionBuilder _ body: () -> Geometry2D) -> Geometry2D {
	body()
}

public func Union(children: [Geometry2D]) -> Geometry2D {
	Union2D(children: children)
}

public extension Geometry2D {
	func adding(@SequenceBuilder _ bodies: () -> [Geometry2D]) -> Geometry2D {
		Union2D(children: [self] + bodies())
	}
}
