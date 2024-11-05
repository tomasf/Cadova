import Foundation

internal struct RoundedBoxMask3D: Shape3D {
    let size: Vector3D
    let cornerRadius: Double
    let mode: Mode

    enum Mode {
        case full
        case top
    }

    init(size: Vector3D, cornerRadius: Double, mode: Mode) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.mode = mode
        precondition(size.x >= cornerRadius * 2 && size.y >= cornerRadius * 2 && size.z >= cornerRadius * 2, "Size must be at least cornerRadius * 2 in each dimension.")
    }

    var body: any Geometry3D {
        readEnvironment { environment in
            let facets = environment.facets.facetCount(circleRadius: cornerRadius) / 4

            struct BoxParameters: Hashable {
                let radius: Double
                let size: Vector3D
                let facets: Int
                let mode: Mode

                var sectors: Int { facets * 4 }
                var levels: Int { mode == .full ? facets * 2 : facets }
            }

            struct Position: Hashable {
                let sector: Int
                let level: Int
                let box: BoxParameters

                init(sector: Int, level: Int, box: BoxParameters) {
                    var resolvedSector = sector % box.sectors

                    if level == 0 || (box.mode == .full && level == box.levels - 1) {
                        resolvedSector = resolvedSector / box.facets * box.facets
                    }

                    self.sector = resolvedSector
                    self.level = level
                    self.box = box
                }

                var point: Vector3D {
                    let quadrant = sector / box.facets
                    let sectorAngle = (Double(quadrant) + Double(sector % box.facets) / Double(box.facets - 1)) * 90°
                    let hemisphere = level / box.facets
                    let levelAngle = (Double(hemisphere) + Double(level % box.facets) / Double(box.facets - 1) - 1) * 90°

                    let mirrorAxes = Axes3D()
                        .union(quadrant == 1 || quadrant == 2 ? .x : [])
                        .union(quadrant > 1 ? .y : [])
                        .union(hemisphere > 0 ? .z : [])

                    var offset = (box.size / 2 - box.radius) * (Vector3D(1).with(mirrorAxes, as: -1))
                    if box.mode == .top && self.level == box.levels - 1 {
                        offset.z += box.radius - box.size.z
                    }

                    return AffineTransform3D.translation(x: box.radius)
                        .rotated(y: levelAngle)
                        .rotated(z: sectorAngle)
                        .translated(offset)
                        .apply(to: .zero)
                }
            }

            let parameters = BoxParameters(radius: cornerRadius, size: size, facets: facets, mode: mode)

            let sides = (0..<parameters.sectors).flatMap { sector -> [[Position]] in
                (0..<parameters.levels-1).map { level in [
                    Position(sector: sector, level: level, box: parameters),
                    Position(sector: sector + 1, level: level, box: parameters),
                    Position(sector: sector + 1, level: level + 1, box: parameters),
                    Position(sector: sector, level: level + 1, box: parameters)
                ]}
            }

            let top = (0..<4).reversed().map {
                Position(sector: $0 * parameters.facets, level: 0, box: parameters)
            }

            let bottom = if mode == .full {
                (0..<4).map {
                    Position(sector: $0 * parameters.facets, level: parameters.levels - 1, box: parameters)
                }
            } else {
                (0..<parameters.sectors).map {
                    Position(sector: $0, level: parameters.levels - 1, box: parameters)
                }
            }

            return Polyhedron(faces: sides + [top, bottom], value: \.point)
        }
    }
}
