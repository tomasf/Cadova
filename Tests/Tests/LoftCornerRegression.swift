import Foundation
import Testing
@testable import Cadova

struct LoftCornerRegressionTests {
    @Test func `adaptive loft sampling emits a sane ring sequence around line to curve corners`() {
        let path = BezierPath3D(from: [0, 0, 0]) {
            line(x: 0, y: 0, z: 20)
            curve(controlX: 10, controlY: 0, controlZ: 30, endX: 20, endY: 0, endZ: 40)
        }
        let environment = EnvironmentValues.defaultEnvironment
        let reference = Direction2D.down
        let target = ReferenceTarget.direction(.negativeZ)
        let frames = path.frames(
            environment: environment,
            target: target,
            targetReference: reference,
            perpendicularBounds: .init(minimum: [-10, -10], maximum: [10, 10]),
            miteringCorners: true
        )
        #expect(frames.filter { $0.miterStretch != nil }.count == 1)

        let circleish = SimplePolygon((0..<32).map {
            let angle = Double($0) / 32 * 360°
            return Vector2D(cos(angle) * 10, sin(angle) * 10)
        })
        let square = SimplePolygon([
            [-10, -10], [10, -10], [10, 10], [-10, 10],
        ]).resampled(count: 32)
        let groups = [SimplePolygonList([circleish, square])]
        let sections = [
            Loft.ResamplingSection(distance: 0, transition: .interpolated(.linear), tree: .empty),
            Loft.ResamplingSection(distance: 40, transition: .interpolated(.linear), tree: .empty),
        ]

        let interpolated = Loft.interpolatePolygonGroups(
            for: groups,
            sections: sections,
            frames: frames,
            curve: path,
            reference: reference,
            target: target,
            environment: environment
        )
        let offsets = interpolated[0].transforms.map(\.offset)

        #expect(offsets.count < 1_000)
        for (previous, next) in offsets.paired() {
            #expect(previous.distance(to: next) > 1e-7)
        }

        let cornerOffsets = offsets.filter { $0.distance(to: [0, 0, 20]) < 1e-7 }
        #expect(cornerOffsets.count == 1)
    }

    @Test func `mitered loft corners skip regular rings inside the oblique cut interval`() throws {
        let path = BezierPath3D(from: [0, 0, 0]) {
            line(x: 0, y: 0, z: 20)
            curve(controlX: 10, controlY: 0, controlZ: 30, endX: 20, endY: 0, endZ: 40)
        }
        let environment = EnvironmentValues.defaultEnvironment
        let reference = Direction2D.down
        let target = ReferenceTarget.direction(.negativeZ)
        let frames = path.frames(
            environment: environment,
            target: target,
            targetReference: reference,
            perpendicularBounds: .init(minimum: [-10, -10], maximum: [10, 10]),
            miteringCorners: true
        )

        let square = SimplePolygon([
            [-10, -10], [10, -10], [10, 10], [-10, 10],
        ])
        let groups = [SimplePolygonList([square, square])]
        let sections = [
            Loft.ResamplingSection(distance: 0, transition: .interpolated(.linear), tree: .empty),
            Loft.ResamplingSection(distance: 40, transition: .interpolated(.linear), tree: .empty),
        ]

        let interpolated = Loft.interpolatePolygonGroups(
            for: groups,
            sections: sections,
            frames: frames,
            curve: path,
            reference: reference,
            target: target,
            environment: environment
        )
        let polygons = interpolated[0].polygons
        let transforms = interpolated[0].transforms
        let cornerPoint = Vector3D(0, 0, 20)
        let miterIndex = try #require(transforms.firstIndex {
            $0.offset.distance(to: cornerPoint) < 1e-7
        })
        #expect(miterIndex > transforms.startIndex)
        #expect(miterIndex < transforms.index(before: transforms.endIndex))

        let miterPoints = polygons[miterIndex].map {
            transforms[miterIndex].apply(to: Vector3D($0, z: 0))
        }
        let incomingDirection = Vector3D(z: 1)
        let outgoingDirection = Vector3D(x: 1, z: 1).normalized
        let incomingClearance = -miterPoints.map { ($0 - cornerPoint) ⋅ incomingDirection }.min()!
        let outgoingClearance = miterPoints.map { ($0 - cornerPoint) ⋅ outgoingDirection }.max()!

        let previousOffset = transforms[transforms.index(before: miterIndex)].offset
        let nextOffset = transforms[transforms.index(after: miterIndex)].offset
        let previousClearance = (cornerPoint - previousOffset).magnitude
        let nextClearance = (nextOffset - cornerPoint).magnitude

        #expect(previousClearance >= incomingClearance - 1e-7)
        #expect(nextClearance >= outgoingClearance - 1e-7)
    }
}
