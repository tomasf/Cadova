import Foundation

struct BezierCurve {
	let points: [Vector2D]

	init(points: [Vector2D]) {
		precondition(points.count >= 2)
		self.points = points
	}

	func point(at fraction: Double) -> Vector2D {
		var workingPoints = self.points
		while workingPoints.count > 1 {
			workingPoints = workingPoints.paired().map { p1, p2 in
				p1.point(alongLineTo: p2, at: fraction)
			}
		}
		return workingPoints[0]
	}

	func points(in range: Range<Double>, minAngle: Angle, minSegmentLength: Double) -> [Vector2D] {
		let startPoint = point(at: range.lowerBound)
		let endPoint = point(at: range.upperBound)
		let midFraction = (range.lowerBound + range.upperBound) / 2
		let midPoint = point(at: midFraction)

		let distance1 = startPoint.distance(to: midPoint)
		let distance2 = midPoint.distance(to: endPoint)

		let angle = abs(startPoint.angle(to: midPoint) - midPoint.angle(to: endPoint))

		if distance1 + distance2 < minSegmentLength && angle < minAngle {
			return []
		}

		return points(in: range.lowerBound..<midFraction, minAngle: minAngle, minSegmentLength: minSegmentLength)
			+ [midPoint]
			+ points(in: midFraction..<range.upperBound, minAngle: minAngle, minSegmentLength: minSegmentLength)
	}

	func points(minAngle: Angle, minSegmentLength: Double) -> [Vector2D] {
		return [point(at: 0)] + points(in: 0..<1, minAngle: minAngle, minSegmentLength: minSegmentLength) + [point(at: 1)]
	}

	func points(segmentCount: Int) -> [Vector2D] {
		let segmentLength = 1.0 / Double(segmentCount)
		return (0...segmentCount).map { f in
			point(at: Double(f) * segmentLength)
		}
	}

	func points(facets: Environment.Facets) -> [Vector2D] {
		guard points.count > 2 else {
			return points
		}

		switch facets {
		case .fixed (let count):
			return points(segmentCount: count)
		case .dynamic(let minAngle, let minSize):
			return points(minAngle: minAngle, minSegmentLength: minSize)
		}
	}

    func transform(using transform: AffineTransform2D) -> BezierCurve {
        BezierCurve(points: points.map { point in
            transform.apply(to: point)
        })
    }
}

public struct BezierPath {
	let startPoint: Vector2D
	let curves: [BezierCurve]

	var endPoint: Vector2D {
		curves.last?.points.last ?? startPoint
	}

	private init(startPoint: Vector2D, curves: [BezierCurve]) {
		self.startPoint = startPoint
		self.curves = curves
	}

	public init(startPoint: Vector2D) {
		self.init(startPoint: startPoint, curves: [])
	}

	func adding(curve: BezierCurve) -> BezierPath {
		let newCurves = curves + [curve]
		return BezierPath(startPoint: startPoint, curves: newCurves)
	}

	public func addingLine(to point: Vector2D) -> BezierPath {
		adding(curve: BezierCurve(points: [endPoint, point]))
	}

	public func addingQuadraticCurve(controlPoint: Vector2D, end: Vector2D) -> BezierPath {
		adding(curve: BezierCurve(points: [endPoint, controlPoint, end]))
	}

	public func addingCubicCurve(controlPoint1: Vector2D, controlPoint2: Vector2D, end: Vector2D) -> BezierPath {
		adding(curve: BezierCurve(points: [endPoint, controlPoint1, controlPoint2, end]))
	}

	public func points(facets: Environment.Facets) -> [Vector2D] {
		return [startPoint] + curves.map { curve in
			Array(curve.points(facets: facets)[1...])
		}.joined()
	}

    public func transform(using transform: AffineTransform2D) -> BezierPath {
        BezierPath(
            startPoint: transform.apply(to: startPoint),
            curves: curves.map { $0.transform(using: transform) }
        )
    }
}
