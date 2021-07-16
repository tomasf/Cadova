import Foundation

public struct Polygon: CoreGeometry2D {
	let source: PolygonSource

	public init(_ points: [Vector2D]) {
		source = Points(points: points)
	}

    public init(_ bezierPath: BezierPath) {
        source = bezierPath
    }

	func call(in environment: Environment) -> SCADCall {
		return SCADCall(
			name: "polygon",
            params: ["points": source.points(in: environment)]
		)
	}
}

protocol PolygonSource {
    func points(in environment: Environment) -> [Vector2D]
}

struct Points: PolygonSource {
    let points: [Vector2D]

    func points(in environment: Environment) -> [Vector2D] {
        self.points
    }
}

extension BezierPath: PolygonSource {
    func points(in environment: Environment) -> [Vector2D] {
        points(facets: environment.facets)
    }
}
