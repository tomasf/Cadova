import Testing
@testable import SwiftSCAD

struct BezierCurveTests {
    @Test func quadraticCurvePoints() {
        let curve = BezierPath2D.Curve(controlPoints: [
            [2.5, 8], [19.3, 25], [27, 10]
        ])

        let points = curve.points(facets: .fixed(10))
        #expect(points ≈ [[2.5, 8], [5.769, 11.08], [8.856, 13.52], [11.761, 15.32], [14.484, 16.48], [17.025, 17], [19.384, 16.88], [21.561, 16.12], [23.556, 14.72], [25.369, 12.68], [27, 10]])
    }

    @Test func cubicCurvePoints() {
        let curve = BezierPath2D.Curve(controlPoints: [
            [12.5, 8], [19.3, 25], [30.2, 12], [27, 10]
        ])

        let points = curve.points(facets: .fixed(10))
        #expect(points ≈ [[12.5, 8], [14.6448, 12.241], [16.9264, 14.928], [19.2356, 16.307], [21.4632, 16.624], [23.5, 16.125], [25.2368, 15.056], [26.5644, 13.663], [27.3736, 12.192], [27.5552, 10.889], [27, 10]])
    }

    @Test func quartic3DCurvePoints() {
        let curve = BezierPath3D.Curve(controlPoints: [
            [11, 12.5, 8], [19.3, 56, 25], [30.2, 41.5, 12], [-12, 3.5, 20], [19, 27, 10]
        ])

        let points = curve.points(facets: .fixed(10))
        #expect(points ≈ [[11, 12.5, 8], [14.2714, 26.5631, 13.195], [16.7728, 34.5648, 15.888], [17.8226, 37.5151, 16.979], [17.176, 36.5448, 17.152], [15.025, 32.9062, 16.875], [11.9984, 27.9728, 16.4], [9.1618, 23.239, 15.763], [8.0176, 20.3208, 14.784], [10.505, 20.955, 13.067], [19, 27, 10]])
    }
}
