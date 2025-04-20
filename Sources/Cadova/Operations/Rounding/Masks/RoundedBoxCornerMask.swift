import Foundation

internal struct RoundedBoxCornerMask: Shape3D {
    let boxSize: Vector3D
    let radius: Double

    @Environment(\.segmentation) var segmentation

    init(boxSize: Vector3D, radius: Double) {
        precondition(boxSize.allSatisfy { $0 >= radius }, "All box dimensions must be >= radius")
        self.boxSize = boxSize
        self.radius = radius
    }

    private enum Vertex: Hashable {
        case outer (sector: Int, level: Int)
        case innerLower
        case innerUpper

        func point(corner: RoundedBoxCornerMask, segmentCount: Int) -> Vector3D {
            switch self {
            case .innerLower: return Vector3D(corner.boxSize.x, corner.boxSize.y, 0)
            case .innerUpper: return corner.boxSize

            case .outer(let sector, let level):
                let resolvedRange = 0...(segmentCount)
                let sectorAngle = Double(sector.clamped(to: resolvedRange)) / Double(segmentCount) * 90°
                let levelAngle =  Double(level.clamped(to: resolvedRange)) / Double(segmentCount) * 90°

                var point = AffineTransform3D.identity
                    .translated(x: -corner.radius)
                    .rotated(y: levelAngle - 90°, z: sectorAngle)
                    .translated(.init(corner.radius))
                    .offset

                if sector < 0 {
                    point.y = corner.boxSize.y
                } else if sector > segmentCount {
                    point.x = corner.boxSize.x
                }

                if level > segmentCount {
                    point.z = corner.boxSize.z
                }

                return point
            }
        }
    }

    var body: any Geometry3D {
        let segmentCount = max(segmentation.segmentCount(circleRadius: radius) / 4, 1)

        let curvedSurface: [[Vertex]] = (-1...segmentCount).flatMap { sector in
            (0...segmentCount).map { level in [
                .outer(sector: sector, level: level + 1),
                .outer(sector: sector + 1, level: level + 1),
                .outer(sector: sector + 1, level: level),
                .outer(sector: sector, level: level),
            ]}
        }

        let bottom = [[
            .outer(sector: -1, level: 0),
            .outer(sector: 0, level: 0),
            .outer(sector: segmentCount + 1, level: 0),
            Vertex.innerLower
        ]]

        let walls: [[Vertex]] = [
            [.innerUpper, .innerLower] + (0...segmentCount + 1).map { .outer(sector: segmentCount + 1, level: $0) }, // X
            [.innerLower, .innerUpper] + (0...segmentCount + 1).reversed().map { .outer(sector: -1, level: $0) },  // Y
            [.innerUpper] + (-1...segmentCount + 1).reversed().map { .outer(sector: $0, level: segmentCount + 1) }   // Z
        ]

        return Polyhedron(faces: curvedSurface + bottom + walls) {
            $0.point(corner: self, segmentCount: segmentCount)
        }
    }
}
