import Foundation

fileprivate struct SegmentedMask {
    let boxSize: Vector3D
    let radius: Double
    let segmentCount: Int
    let cornerStyle: CornerRoundingStyle

    fileprivate enum Vertex: Hashable {
        case surface (sector: Int, level: Int)
        case innerLower
        case innerUpper
    }

    private func surface(sector: Int, level: Int) -> Vertex {
        // Make sure the bottommost surface vertex where the curved edges meet is the same regardless of sector
        let resolvedSector = level == 0 && (0...segmentCount) ~= sector ? 0 : sector
        return .surface(sector: resolvedSector, level: level)
    }

    func resolve(vertex: Vertex) -> Vector3D {
        switch vertex {
        case .innerLower: return Vector3D(boxSize.x, boxSize.y, 0)
        case .innerUpper: return boxSize

        case .surface(let sector, let level):
            let resolvedRange = 0...(segmentCount)
            let sectorAngle = Double(sector.clamped(to: resolvedRange)) / Double(segmentCount) * 90°
            let levelAngle = Double(level.clamped(to: resolvedRange)) / Double(segmentCount) * 90°

            let center = Vector3D(radius)
            var point = Transform3D.identity
                .translated(x: -radius)
                .rotated(y: levelAngle - 90°, z: sectorAngle)
                .offset

            if cornerStyle != .circular {
                let exponent = cornerStyle.exponent
                let denom = pow(Swift.abs(point.x), exponent) + pow(Swift.abs(point.y), exponent) + pow(Swift.abs(point.z), exponent)
                point *= pow(pow(radius, exponent) / denom, 1.0 / exponent)
            }

            point += center

            if sector < 0 {
                point.y = boxSize.y
            } else if sector > segmentCount {
                point.x = boxSize.x
            }
            if level > segmentCount {
                point.z = boxSize.z
            }

            return point
        }
    }

    var faces: [[Vertex]] {
        let curvedSurface: [[Vertex]] = (-1...segmentCount).flatMap { sector in
            (0...segmentCount).map { level in [
                surface(sector: sector, level: level),
                surface(sector: sector + 1, level: level),
                surface(sector: sector + 1, level: level + 1),
                surface(sector: sector, level: level + 1),
            ]}
        }
        let bottom = [
            Vertex.innerLower,
            surface(sector: segmentCount + 1, level: 0),
            surface(sector: 0, level: 0),
            surface(sector: -1, level: 0),
        ]
        let xWall: [Vertex] = [.innerLower, .innerUpper] + (0...segmentCount + 1).reversed().map {
            surface(sector: segmentCount + 1, level: $0)
        }
        let yWall: [Vertex] = [.innerUpper, .innerLower] + (0...segmentCount + 1).map {
            surface(sector: -1, level: $0)
        }
        let zWall: [Vertex] = [.innerUpper] + (-1...segmentCount + 1).map {
            surface(sector: $0, level: segmentCount + 1)
        }
        return curvedSurface + [bottom, xWall, yWall, zWall]
    }
}

internal struct RoundedBoxCornerMask: Shape3D {
    let boxSize: Vector3D
    let radius: Double

    init(boxSize: Vector3D, radius: Double) {
        precondition(boxSize.allSatisfy { $0 >= radius }, "All box dimensions must be >= radius")
        self.boxSize = boxSize
        self.radius = radius
    }

    var body: any Geometry3D {
        @Environment(\.segmentation) var segmentation
        @Environment(\.cornerRoundingStyle) var roundedCornerStyle
        let segmentCount = max(segmentation.segmentCount(circleRadius: radius) / 4 - 1, 1)

        CachedNode(name: "roundedBoxCornerMask", parameters: boxSize, radius, segmentCount) {
            let segmentedMask = SegmentedMask(boxSize: boxSize, radius: radius, segmentCount: segmentCount, cornerStyle: roundedCornerStyle)

            return Mesh(faces: segmentedMask.faces) {
                segmentedMask.resolve(vertex: $0)
            }
        }
    }
}
