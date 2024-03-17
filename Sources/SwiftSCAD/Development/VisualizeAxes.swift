import Foundation

public extension Geometry3D {
    func visualizingAxes(scale: Double = 1) -> any Geometry3D {
        let length = 30.0
        let arrow = Cylinder(diameter: 1, height: length)
            .adding {
                Cylinder(bottomDiameter: 2, topDiameter: 0, height: 2)
                    .translated(z: length)
            }

        return self.adding {
            Box(2, center: .all)
                .colored(.white)
                .adding {
                    arrow.rotated(y: 90°)
                        .colored(.red)
                    arrow.rotated(x: -90°)
                        .colored(.green)
                    arrow
                        .colored(.blue)
                }
                .scaled(scale)
                .usingFacets(count: 8)
        }
    }
}

public extension Geometry2D {
    func visualizingAxes(scale: Double = 1) -> any Geometry2D {
        let length = 30.0
        let arrow = Rectangle([length - 1, 1], center: .y)
            .translated(x: 1)
            .adding {
                Polygon([[0, 1], [2, 0], [0, -1]])
                    .translated(x: length)
            }

        return self.adding {
            Rectangle(2, center: .all)
                .colored(.white)
                .adding {
                    arrow
                        .colored(.red)
                    arrow.rotated(90°)
                        .colored(.green)
                }
                .scaled(scale)
        }
    }
}
