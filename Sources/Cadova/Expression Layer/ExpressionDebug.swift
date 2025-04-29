import Foundation

extension String {
    var indented: String {
        "    " + self.replacingOccurrences(of: "\n", with: "\n    ")
    }
}

extension GeometryExpression2D {
    public var debugDescription: String {
        switch contents {
        case .empty:
            "empty"
        case .shape (let primitiveShape):
            primitiveShape.debugDescription
        case .boolean (let array, let type):
            "\(String.init(describing: type)) {\n\(array.map(\.debugDescription).joined(separator: "\n").indented)\n}"
        case .transform (let body, let transform):
            String(format: "transform(%@) {\n%@\n}",
                   String(describing: transform.values),
                   body.debugDescription.indented
            )
        case .convexHull (let body):
            "convexHull {\n\(body.debugDescription.indented)\n}"
        case .materialized (let key):
            String(format: "materialized: %@", key.debugDescription)
        case .offset (let body, let amount, let joinStyle, let miterLimit, let segmentCount):
            String(format: "offset(%g, style: %@, miterLimit: %g, segments: %d) {\n%@\n}",
                   amount,
                   String(describing: joinStyle),
                   miterLimit,
                   segmentCount,
                   body.debugDescription.indented
            )
        case .projection (let body, let type):
            switch type {
            case .full: String(format: "projection {\n%@\n}", body.debugDescription.indented)
            case .slice (let z): String(format: "slice(z: %g) {\n%@\n}", z, body.debugDescription.indented)
            }
        }
    }
}

extension GeometryExpression2D.PrimitiveShape {
    var debugDescription: String {
        switch self {
        case .rectangle(let size):
            String(format: "rectangle(x: %g, y: %g)", size.x, size.y)
        case .circle(let radius, let segmentCount):
            String(format: "circle(radius: %g, segments: %d)", radius, segmentCount)
        case .polygon(let points, let fillRule):
            String(format: "polygon(fillRule: %@) { %@ }", String(describing: fillRule), points.map {
                String(format: "[%g, %g]", $0.x, $0.y)
            }.joined(separator: ", "))
        }
    }
}

extension GeometryExpression3D {
    public var debugDescription: String {
        switch contents {
        case .empty:
            "empty"
        case .shape (let primitiveShape):
            primitiveShape.debugDescription
        case .boolean (let array, let type):
            "\(String.init(describing: type)) {\n\(array.map(\.debugDescription).joined(separator: "\n").indented)\n}"
        case .transform (let body, let transform):
            String(format: "transform(%@) {\n%@\n}",
                   String(describing: transform.values),
                   body.debugDescription.indented
            )
        case .convexHull (let body):
            "convexHull {\n\(body.debugDescription.indented)\n}"
        case .materialized (let key):
            String(format: "materialized: %@", key.debugDescription)

        case .extrusion (let body, let type):
            switch type {
            case let .linear(height, twist, divisions, scaleTop):
                String(format: "extrude(linear, height: %g, twist: %@, divisions: %d, scaleTop: (%g, %g)) {\n%@\n}",
                       height, twist.debugDescription, divisions, scaleTop.x, scaleTop.y,
                       body.debugDescription.indented
                )

            case let .rotational(angle, segments):
                String(format: "extrude(rotated, angle: %@, segments: %d)", angle.debugDescription, segments)
            }
        case let .applyMaterial(body, material):
            "applyMaterial (\(material)) {\n\(body.debugDescription.indented)\n}"
        case let .lazyUnion(children):
            "lazyUnion {\n\(children.map(\.debugDescription).joined(separator: "\n").indented)\n}"
        }
    }
}

extension GeometryExpression3D.PrimitiveShape {
    var debugDescription: String {
        switch self {
        case .box(let size):
            String(format: "box(x: %g, y: %g, z: %g)", size.x, size.y, size.z)
        case .sphere(let radius, let segmentCount):
            String(format: "sphere(radius: %g, segments: %d)", radius, segmentCount)
        case .cylinder (let bottomRadius, let topRadius, let height, let segmentCount):
            String(format: "cylinder(bottom R: %g, top R: %g, height: %g, segments: %d)", bottomRadius, topRadius, height, segmentCount)
        case .mesh:
            "mesh(...)"
        case .convexHull (let points):
            String(format: "hull { %@ }", points.map {
                String(format: "[%g, %g]", $0.x, $0.y)
            }.joined(separator: ", "))
        }
    }
}
