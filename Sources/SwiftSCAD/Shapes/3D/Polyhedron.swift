import Foundation

public struct Polyhedron: CoreGeometry3D {
	let points: [Vector3D]
	let faces: [[Int]]
	let convexity: Int

	public init(points: [Vector3D], faces: [[Int]], convexity: Int = 1) {
		assert(points.count >= 4, "At least four points are needed for a polyhedron")
		assert(faces.allSatisfy { $0.count >= 3 }, "Each face must contain at least three points")
		assert(faces.allSatisfy { $0.allSatisfy { $0 < points.count } }, "Each face must contain indexes from the points array")

		self.points = points
		self.faces = faces
		self.convexity = convexity
	}

	public init(faces vectorFaces: [[Vector3D]], convexity: Int = 1) {
		var points: [Vector3D] = []

		let faces = vectorFaces.map { vectors -> [Int] in
			assert(vectors.count >= 3, "Each face must contain at least three points")

			return vectors.map { vector in
				if let index = points.firstIndex(of: vector) {
					return Int(index)
				} else {
					points.append(vector)
					return points.count - 1
				}
			}
		}

		self.init(points: points, faces: faces, convexity: convexity)
	}


	func call(in environment: Environment) -> SCADCall {
		SCADCall(
			name: "polyhedron",
			params: [
				"points": points,
				"faces": faces,
				"convexity": convexity
			]
		)
	}
}
