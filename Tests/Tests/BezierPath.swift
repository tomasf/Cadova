import Testing
@testable import SwiftSCAD

struct BezierPathTests {
    let linearPoints: [Vector3D] = [[56.2, 64, 2], [25.1, 34, 100], [0, -24, 55]]
    let linearPath: BezierPath3D

    let quadraticPath = BezierPath2D(startPoint: [39.1, 150])
        .addingQuadraticCurve(controlPoint: [20.1, 55], end: [0, 500])
        .addingCurve([320, 82.3], [393, 0])

    init() {
        linearPath = BezierPath3D(linesBetween: linearPoints)
    }

    @Test func linearAllPoints() {
        let points = linearPath.points(facets: .fixed(10))
        let points2 = linearPath.points(facets: .defaults)
        // Optimization makes sure linear curves simply resolve to the control points, regardless of facets
        #expect(points ≈ linearPoints)
        #expect(points2 ≈ linearPoints)
    }

    @Test func linearAllPointsClosed() {
        let points = linearPath.closed().points(facets: .fixed(10))
        #expect(points ≈ (linearPoints + [linearPoints[0]]))
    }

    @Test func linearLimitedRange() {
        let rangePoints = linearPath.points(in: 0.5...1.5, facets: .fixed(10))
        let rangePoints2 = linearPath.points(in: 0.5...1.5, facets: .defaults)
        let expectedRangePoints: [Vector3D] = [
            linearPoints[0].point(alongLineTo: linearPoints[1], at: 0.5),
            linearPoints[1],
            linearPoints[1].point(alongLineTo: linearPoints[2], at: 0.5)
        ]

        // Similar optimization for range points
        #expect(rangePoints ≈ expectedRangePoints)
        #expect(rangePoints2 ≈ expectedRangePoints)
    }

    @Test func linearExtendedRange() {
        let extendedRangePoints = linearPath.points(in: -0.5...2.5, facets: .fixed(10))
        let expectedExtendedRangePoints: [Vector3D] = [
            linearPoints[0].point(alongLineTo: linearPoints[1], at: -0.5),
            linearPoints[1],
            linearPoints[1].point(alongLineTo: linearPoints[2], at: 1.5)
        ]
        #expect(extendedRangePoints ≈ expectedExtendedRangePoints)
    }

    @Test func quadraticPointsFixed() {
        let points = quadraticPath.points(facets: .fixed(5))
        #expect(points ≈ [[39.1, 150], [31.456, 133.6], [23.724, 160.4], [15.904, 230.4], [7.996, 343.6], [0, 500], [118.12, 346.336], [216.48, 219.504], [295.08, 119.504], [353.92, 46.336], [393, 0]])
    }

    @Test func quadraticPointsDynamic() {
        let points = quadraticPath.points(facets: .dynamic(minAngle: 10°, minSize: 20))
        #expect(points ≈ [[39.1, 150], [34.3328, 134.688], [29.5312, 136.25], [24.6953, 154.688], [22.2645, 170.234], [19.825, 190], [18.6021, 201.465], [17.377, 213.984], [16.1497, 227.559], [14.9203, 242.188], [13.6888, 257.871], [12.4551, 274.609], [11.2192, 292.402], [9.98125, 311.25], [8.74111, 331.152], [8.12024, 341.499], [7.49883, 352.109], [6.87688, 362.983], [6.25439, 374.121], [5.63137, 385.522], [5.00781, 397.188], [4.38372, 409.116], [3.75908, 421.309], [3.13391, 433.765], [2.5082, 446.484], [1.88196, 459.468], [1.25518, 472.715], [0.627856, 486.226], [0, 500], [9.9397, 487.029], [19.7588, 474.221], [29.4573, 461.578], [39.0352, 449.098], [48.4924, 436.781], [57.8291, 424.629], [67.0452, 412.64], [76.1406, 400.816], [85.1155, 389.155], [93.9697, 377.657], [102.703, 366.324], [111.316, 355.154], [119.809, 344.148], [128.181, 333.306], [136.432, 322.627], [144.562, 312.112], [152.573, 301.762], [160.462, 291.574], [168.231, 281.551], [175.879, 271.691], [183.406, 261.996], [190.813, 252.463], [198.1, 243.095], [205.266, 233.891], [212.311, 224.85], [219.235, 215.973], [226.039, 207.26], [232.723, 198.71], [239.285, 190.324], [245.728, 182.103], [252.049, 174.044], [258.25, 166.15], [270.29, 150.853], [281.848, 136.21], [292.923, 122.223], [303.516, 108.891], [313.626, 96.2135], [323.254, 84.1914], [332.399, 72.8244], [341.062, 62.1125], [349.243, 52.0557], [356.941, 42.6539], [364.157, 33.9072], [370.891, 25.8156], [382.91, 11.5977], [393, 0]])
    }
}
