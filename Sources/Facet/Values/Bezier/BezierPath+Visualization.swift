import Foundation

extension BezierPath {
    /// Visualizes the bezier path for debugging purposes by generating a 3D representation. This method creates visual markers for control points and start points, and lines to represent the path and its control lines.
    /// - Parameters:
    ///   - scale: A value that scales the size of markers and the thickness of lines.
    ///   - markerRotation: The rotation to use for markers. Set to nil to hide them.

    public func visualize(scale: Double = 1, markerRotation: Rotation3D? = [45°, 0°, -45°]) -> any Geometry3D {
        @GeometryBuilder3D
        func makeMarker(at location: V, text: String, transform: AffineTransform3D) -> any Geometry3D {
            Box([4, 2, 0.1])
                .roundingBoxCorners(axis: .z, radius: 1)
                .aligned(at: .center)
                .colored(.white)
                .adding {
                    Text(text)
                        .usingFont(size: 1)
                        .usingTextAlignment(horizontal: .center, vertical: .center)
                        .extruded(height: 0.01)
                        .translated(z: 0.1)
                        .colored(.black)
                }
                .translated(y: 1)
                .adding {
                    Sphere(radius: 0.2)
                        .colored(.black)
                }
                .transformed(transform)
                .translated(location.vector3D)
        }

        func makeMarker(at location: V, curveIndex: Int, pointIndex: Int, transform: AffineTransform3D) -> any Geometry3D {
            makeMarker(at: location, text: "c\(curveIndex + 1)p\(pointIndex + 1)", transform: transform)
        }

        func makeLine(from: V, to: V, thickness: Double) -> any Geometry3D {
            Sphere(radius: thickness)
                .translated(from.vector3D)
                .adding {
                    Sphere(radius: thickness)
                        .translated(to.vector3D)
                }
                .convexHull()
                .usingFacets(count: 3)
        }

        return readEnvironment { environment -> any Geometry3D in
            if let markerRotation {
                let transform = AffineTransform3D.scaling(scale).rotated(markerRotation)
                for (curveIndex, curve) in curves.enumerated() {
                    for (pointIndex, controlPoint) in curve.controlPoints.dropFirst().enumerated() {
                        makeMarker(at: controlPoint, curveIndex: curveIndex, pointIndex: pointIndex, transform: transform)
                    }
                }
                makeMarker(at: startPoint, text: "Start", transform: transform)
            }

            // Lines between control points
            for curve in curves {
                for (cp1, cp2) in curve.controlPoints.paired() {
                    makeLine(from: cp1, to: cp2, thickness: 0.04 * scale)
                        .colored(.red, alpha: 0.2)
                }
            }

            // Curves
            for (v1, v2) in points(facets: environment.facets).paired() {
                makeLine(from: v1, to: v2, thickness: 0.1 * scale)
                    .colored(.blue)
            }
        }
    }
}
