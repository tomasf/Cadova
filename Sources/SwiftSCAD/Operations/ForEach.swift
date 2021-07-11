import Foundation

public enum ForEachOperation {
	case union
	case intersection
}

struct ForEach3D: Shape {
	let body: Geometry3D

	init<C: Sequence>(_ sequence: C, operation: ForEachOperation, @UnionBuilder body: (C.Element) -> Geometry3D) {
		switch operation {
		case .union:
			self.body = Union3D(children: sequence.map(body))
		case .intersection:
			self.body = Intersection3D(children: sequence.map(body))
		}
	}
}

public func ForEach<C: Sequence>(_ sequence: C, operation: ForEachOperation = .union, @UnionBuilder body: (C.Element) -> Geometry3D) -> Geometry3D {
	ForEach3D(sequence, operation: operation, body: body)
}


struct ForEach2D: Shape2D {
	let body: Geometry2D

	init<C: Sequence>(_ sequence: C, operation: ForEachOperation, @UnionBuilder body: (C.Element) -> Geometry2D) {
		switch operation {
		case .union:
			self.body = Union2D(children: sequence.map(body))
		case .intersection:
			self.body = Intersection2D(children: sequence.map(body))
		}
	}
}

public func ForEach<C: Sequence>(_ sequence: C, operation: ForEachOperation = .union, @UnionBuilder body: (C.Element) -> Geometry2D) -> Geometry2D {
	ForEach2D(sequence, operation: operation, body: body)
}


public extension Sequence {
	func forEach(@UnionBuilder _ transform: (Element) -> Geometry3D) -> Geometry3D {
		Union3D(children: map(transform))
	}

	func forEach(@UnionBuilder _ transform: (Element) -> Geometry2D) -> Geometry2D {
		Union2D(children: map(transform))
	}
}
