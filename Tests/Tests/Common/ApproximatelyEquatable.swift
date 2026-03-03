import Foundation
@testable import Cadova

infix operator ≈: ComparisonPrecedence

protocol ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool
}

extension ApproximatelyEquatable {
    static func ≈(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.equals(rhs, within: 1e-3)
    }
}

extension Double: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        Swift.abs(self - other) < tolerance
    }
}

extension Optional: ApproximatelyEquatable where Wrapped: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case (.none, .none): true
        case (.none, .some), (.some, .none): false
        case (.some(let a), .some(let b)): a.equals(b, within: tolerance)
        }
    }
}

extension Collection where Element: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.count == other.count
        && self.indices.allSatisfy { self[$0].equals(other[$0], within: tolerance) }
    }
}

extension Array where Element: ApproximatelyEquatable {
    func equalsUnordered(_ other: Self, within tolerance: Double) -> Bool {
        guard count == other.count else { return false }

        var unmatched = other
        for value in self {
            guard let index = unmatched.firstIndex(where: { value.equals($0, within: tolerance) }) else {
                return false
            }
            unmatched.remove(at: index)
        }

        return unmatched.isEmpty
    }
}

extension Dictionary where Value: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        count == other.count
        && allSatisfy { key, value in
            guard let otherValue = other[key] else { return false }
            return value.equals(otherValue, within: tolerance)
        }
    }
}

extension Vector2D: ApproximatelyEquatable {}
extension Vector3D: ApproximatelyEquatable {}
extension Array: ApproximatelyEquatable where Element: ApproximatelyEquatable {}

extension Angle: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        degrees.equals(other.degrees, within: tolerance)
    }
}

extension BoundingBox: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.minimum.equals(other.minimum, within: tolerance) && self.maximum.equals(other.maximum, within: tolerance)
    }
}

extension BezierPath: ApproximatelyEquatable where V: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.startPoint ≈ other.startPoint && self.curves ≈ other.curves
    }
}

extension BezierCurve: ApproximatelyEquatable where V: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.controlPoints ≈ other.controlPoints
    }
}

extension Direction: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        self.unitVector.equals(other.unitVector, within: tolerance)
    }
}

extension Transform2D: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        values.equals(other.values, within: tolerance)
    }
}

extension Transform3D: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        values.equals(other.values, within: tolerance)
    }
}

extension Color: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        red.equals(other.red, within: tolerance)
        && green.equals(other.green, within: tolerance)
        && blue.equals(other.blue, within: tolerance)
        && alpha.equals(other.alpha, within: tolerance)
    }
}

extension Material.PhysicalProperties: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        metallicness.equals(other.metallicness, within: tolerance)
        && roughness.equals(other.roughness, within: tolerance)
    }
}

extension Material: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        name == other.name
        && baseColor.equals(other.baseColor, within: tolerance)
        && physicalProperties.equals(other.physicalProperties, within: tolerance)
    }
}

extension Plane: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        offset.equals(other.offset, within: tolerance)
        && normal.equals(other.normal, within: tolerance)
    }
}

extension SimplePolygon: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        vertices.equals(other.vertices, within: tolerance)
    }
}

extension SimplePolygonList: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        polygons.equals(other.polygons, within: tolerance)
    }
}

extension MeshData: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        vertices.equals(other.vertices, within: tolerance)
        && faces == other.faces
    }
}

private func transformsEqual<T>(_ lhs: T, _ rhs: T, within tolerance: Double) -> Bool {
    if let lhs = lhs as? Transform2D, let rhs = rhs as? Transform2D {
        return lhs.equals(rhs, within: tolerance)
    }
    if let lhs = lhs as? Transform3D, let rhs = rhs as? Transform3D {
        return lhs.equals(rhs, within: tolerance)
    }
    return false
}

extension GeometryNode.Projection: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case (.full, .full):
            true
        case let (.slice(a), .slice(b)):
            a.equals(b, within: tolerance)
        case (.full, _), (.slice, _):
            false
        }
    }
}

extension GeometryNode.Extrusion: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case let (.linear(heightA, twistA, divisionsA, scaleTopA), .linear(heightB, twistB, divisionsB, scaleTopB)):
            heightA.equals(heightB, within: tolerance)
            && twistA.equals(twistB, within: tolerance)
            && divisionsA == divisionsB
            && scaleTopA.equals(scaleTopB, within: tolerance)
        case let (.rotational(angleA, segmentsA), .rotational(angleB, segmentsB)):
            angleA.equals(angleB, within: tolerance)
            && segmentsA == segmentsB
        case (.linear, _), (.rotational, _):
            false
        }
    }
}

extension GeometryNode.PrimitiveShape2D: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case let (.rectangle(sizeA), .rectangle(sizeB)):
            sizeA.equals(sizeB, within: tolerance)
        case let (.circle(radiusA, segmentsA), .circle(radiusB, segmentsB)):
            radiusA.equals(radiusB, within: tolerance)
            && segmentsA == segmentsB
        case let (.polygons(listA, fillRuleA), .polygons(listB, fillRuleB)):
            listA.equals(listB, within: tolerance)
            && fillRuleA == fillRuleB
        case let (.convexHull(pointsA), .convexHull(pointsB)):
            pointsA.equals(pointsB, within: tolerance)
        case (.rectangle, _), (.circle, _), (.polygons, _), (.convexHull, _):
            false
        }
    }
}

extension GeometryNode.PrimitiveShape3D: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case let (.box(sizeA), .box(sizeB)):
            sizeA.equals(sizeB, within: tolerance)
        case let (.sphere(radiusA, segmentsA), .sphere(radiusB, segmentsB)):
            radiusA.equals(radiusB, within: tolerance)
            && segmentsA == segmentsB
        case let (.cylinder(bottomA, topA, heightA, segmentsA), .cylinder(bottomB, topB, heightB, segmentsB)):
            bottomA.equals(bottomB, within: tolerance)
            && topA.equals(topB, within: tolerance)
            && heightA.equals(heightB, within: tolerance)
            && segmentsA == segmentsB
        case let (.convexHull(pointsA), .convexHull(pointsB)):
            pointsA.equals(pointsB, within: tolerance)
        case let (.mesh(meshA), .mesh(meshB)):
            meshA.equals(meshB, within: tolerance)
        case (.box, _), (.sphere, _), (.cylinder, _), (.convexHull, _), (.mesh, _):
            false
        }
    }
}

extension GeometryNode.Contents: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        switch (self, other) {
        case (.empty, .empty):
            return true
        case let (.boolean(childrenA, typeA), .boolean(childrenB, typeB)):
            guard typeA == typeB else { return false }
            if typeA == .union {
                return childrenA.equalsUnordered(childrenB, within: tolerance)
            } else {
                return childrenA.equals(childrenB, within: tolerance)
            }
        case let (.transform(bodyA, transformA), .transform(bodyB, transformB)):
            return bodyA.equals(bodyB, within: tolerance) && transformsEqual(transformA, transformB, within: tolerance)
        case let (.convexHull(bodyA), .convexHull(bodyB)):
            return bodyA.equals(bodyB, within: tolerance)
        case let (.refine(bodyA, edgeA), .refine(bodyB, edgeB)):
            return bodyA.equals(bodyB, within: tolerance) && edgeA.equals(edgeB, within: tolerance)
        case let (.simplify(bodyA, toleranceA), .simplify(bodyB, toleranceB)):
            return bodyA.equals(bodyB, within: tolerance) && toleranceA.equals(toleranceB, within: tolerance)
        case let (.select(bodyA, indexA), .select(bodyB, indexB)):
            return bodyA.equals(bodyB, within: tolerance) && indexA == indexB
        case let (.decompose(bodyA), .decompose(bodyB)):
            return bodyA.equals(bodyB, within: tolerance)
        case (.materialized, .materialized):
            return true
        case let (.shape2D(shapeA), .shape2D(shapeB)):
            return shapeA.equals(shapeB, within: tolerance)
        case let (.offset(bodyA, amountA, joinStyleA, miterLimitA, segmentCountA), .offset(bodyB, amountB, joinStyleB, miterLimitB, segmentCountB)):
            return bodyA.equals(bodyB, within: tolerance)
                && amountA.equals(amountB, within: tolerance)
                && joinStyleA == joinStyleB
                && miterLimitA.equals(miterLimitB, within: tolerance)
                && segmentCountA == segmentCountB
        case let (.projection(bodyA, typeA), .projection(bodyB, typeB)):
            return bodyA.equals(bodyB, within: tolerance) && typeA.equals(typeB, within: tolerance)
        case let (.shape3D(shapeA), .shape3D(shapeB)):
            return shapeA.equals(shapeB, within: tolerance)
        case let (.applyMaterial(bodyA, materialA), .applyMaterial(bodyB, materialB)):
            return bodyA.equals(bodyB, within: tolerance) && materialA.equals(materialB, within: tolerance)
        case let (.extrusion(bodyA, typeA), .extrusion(bodyB, typeB)):
            return bodyA.equals(bodyB, within: tolerance) && typeA.equals(typeB, within: tolerance)
        case let (.trim(bodyA, planeA), .trim(bodyB, planeB)):
            return bodyA.equals(bodyB, within: tolerance) && planeA.equals(planeB, within: tolerance)
        case let (.smoothOut(bodyA, minSharpAngleA, minSmoothnessA), .smoothOut(bodyB, minSharpAngleB, minSmoothnessB)):
            return bodyA.equals(bodyB, within: tolerance)
                && minSharpAngleA.equals(minSharpAngleB, within: tolerance)
                && minSmoothnessA.equals(minSmoothnessB, within: tolerance)
        default:
            return false
        }
    }
}

extension GeometryNode: ApproximatelyEquatable {
    func equals(_ other: Self, within tolerance: Double) -> Bool {
        contents.equals(other.contents, within: tolerance)
    }
}
