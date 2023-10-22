//
//  ExtrudeAlong.swift
//  GeoTest
//
//  Created by Tomas Franzén on 2021-07-07.
//

import Foundation

struct ExtrudeAlong: CoreGeometry3D {
    let path: BezierPath
    let radius: Double
    let body: Geometry2D

    private func inset(_ angle1: Angle, _ angle2: Angle) -> Double {
        let half = abs(angle1 - angle2) / Double(2.0)
        return (sin(half) * radius) / sin(90° - half)
    }

    func call(in environment: Environment) -> SCADCall {
        let pairs = path.points(facets: environment.facets).paired()

        let geometry = pairs.enumerated().map { index, points -> Geometry3D in
            let (fromPoint, toPoint) = points
            let length = fromPoint.distance(to: toPoint)
            let angle = fromPoint.angle(to: toPoint)

            let startInset: Double
            let endInset: Double
            let corner: Geometry3D?

            if index > 0 {
                let (prevFromPoint, prevToPoint) = pairs[index-1]
                let prevAngle = prevFromPoint.angle(to: prevToPoint)
                startInset = inset(angle > prevAngle + 180° ? angle - 360° : angle, prevAngle)
            } else {
                startInset = 0
            }

            if index < pairs.count - 1 {
                let (nextP1, nextP2) = pairs[index+1]
                let nextFullAngle = nextP1.angle(to: nextP2)
                let nextAngle = nextFullAngle > angle + 180° ? nextFullAngle - 360° : nextFullAngle

                endInset = inset(angle, nextAngle)
                let offset = angle < nextAngle ? radius : -radius

                corner = body
                    .translated(x: offset)
                    .extruded(angles: Range(-90°, nextAngle - angle - 90°))
                    .translated(x: length - endInset, y: offset)
                    .rotated(z: angle)
                    .translated(Vector3D(fromPoint))
            } else {
                endInset = 0
                corner = nil
            }

            return body.extruded(height: length - startInset - endInset + 0.0002)
                .translated(z: endInset - 0.0001)
                .translated(z: -length)
                .rotated(x: 90°, z: angle - 90°)
                .translated(Vector3D(fromPoint))
                .adding(corner)
        }
        return Union3D(children: geometry)
            .call(in: environment)
    }
}

public extension Geometry2D {
    /// Extrude a 2D shape along a Bezier path
    ///
    /// The origin of the 2D shape is centered on the path, rounding corners where needed, with the Y axis in 2D becoming the Z axis in 3D.
    /// - Parameters:
    ///   - path: The bezier path to use as a guide in the X-Y plane.
    ///   - radius: The corner radius of the extruded geometry. This should be greater than or equal to the distance between the origin and the furthest point along the X axis of the 2D shape. For example, extruding `Rectangle([14, 3], center: .all)` requires at least 7 as the radius.
    func extruded(along path: BezierPath, radius: Double) -> Geometry3D {
        ExtrudeAlong(path: path, radius: radius, body: self)
    }
}
