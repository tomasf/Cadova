import Foundation

internal struct ChamferedFillet {
    let radius: Double
    let overhang: Angle

    init(radius: Double, overhang: Angle) {
        precondition(radius > 0, "Overhang fillets require a radius greater than zero")
        precondition(overhang > 0° && overhang < 90°, "Angle must be between 0 and 90 degrees")
        self.radius = radius
        self.overhang = overhang
    }
}

extension ChamferedFillet: EdgeProfileShape {
    func shape(angle: Angle) -> any Geometry2D {
        assertionFailure("shape(angle:) is not implemented for OverhangFillet")
        return Rectangle(0)
    }

    var height: Double {
        radius
    }

    var arcEnd: Vector2D {
        .init(cos(overhang) * radius, sin(overhang) * radius)
    }

    var topInset: Double {
        radius / 2 * sqrt(2 * (1 - sin(overhang))) / sin(45° + overhang / 2)
    }

    func inset(at z: Double) -> Double {
        return if z < arcEnd.y {
            (sqrt(1 - pow(z / radius, 2)) - 1) * -radius
        } else {
            radius - arcEnd.x + (arcEnd.x - topInset) * (z - arcEnd.y) / (radius - arcEnd.y)
        }
    }

    func convexMask(shape: any Geometry2D, extrusionHeight: Double) -> any Geometry3D {
        EnvironmentReader3D { environment in
            let facetsPerRev = environment.facets.facetCount(circleRadius: radius)
            let facetCount = max(Int(ceil(Double(facetsPerRev) / (360° / overhang))), 1)

            return (0...facetCount).map { f in
                let angle = (Double(f) / Double(facetCount)) * overhang
                return shape.offset(amount: (cos(angle) - 1) * radius, style: .round)
                    .extruded(height: extrusionHeight - radius + sin(angle) * radius)
            }
            .adding {
                shape.offset(amount: topInset - radius, style: .round)
                    .extruded(height: extrusionHeight)
            }
            .convexHull()
        }
    }
}
