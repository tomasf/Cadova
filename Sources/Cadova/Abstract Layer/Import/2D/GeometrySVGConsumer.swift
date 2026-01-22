import Foundation
internal import SwiftDraw

/// Cadova's consumer that produces Geometry2D directly.
internal struct GeometrySVGConsumer: SVGShapeConsumer {
    let segmentation: Segmentation
    let scale: Double
    let origin: Import<D2>.SVGOrigin

    /// Pixels per millimeter according to the SVG/CSS standard (96 pixels per inch).
    private static let pixelsPerMillimeter = 96.0 / 25.4

    init(segmentation: Segmentation, scale: Import<D2>.SVGScale, origin: Import<D2>.SVGOrigin) {
        self.segmentation = segmentation
        self.origin = origin
        self.scale = switch scale {
        case .physical: 1.0 / Self.pixelsPerMillimeter
        case .pixels: 1.0
        }
    }

    struct Subpath {
        let bezierPath: BezierPath2D
        let isClosed: Bool
    }

    func makePoint(x: Double, y: Double) -> Vector2D {
        Vector2D(x: x * scale, y: y * scale)
    }

    func makePathBuilder() -> any SVGPathBuilder<Vector2D, [Subpath]> {
        GeometrySVGPathBuilder(scale: scale)
    }

    func makeShape(path: [Subpath], fill: SVGFillInfo?, stroke: SVGStrokeInfo?) -> (any Geometry2D)? {
        var geometries: [any Geometry2D] = []

        // Build fill geometry
        if let fill {
            let fillRule = FillRule(from: fill.rule)
            var polygons: [SimplePolygon] = []
            for subpath in path where subpath.isClosed {
                let points = subpath.bezierPath.points(segmentation: segmentation)
                if points.count >= 3 {
                    polygons.append(SimplePolygon(points))
                }
            }
            if !polygons.isEmpty {
                let node = GeometryNode<D2>(.shape2D(.polygons(SimplePolygonList(polygons), fillRule: fillRule)))
                geometries.append(NodeBasedGeometry(node))
            }
        }

        // Build stroke geometry
        if let stroke {
            let join = LineJoinStyle(from: stroke.lineJoin)
            let cap = LineCapStyle(from: stroke.lineCap)
            let scaledWidth = stroke.width * scale

            for subpath in path {
                let strokeGeom: any Geometry2D
                if subpath.isClosed {
                    let points = subpath.bezierPath.points(segmentation: segmentation)
                    if points.count >= 3 {
                        strokeGeom = Polygon(points).stroked(width: scaledWidth, alignment: .centered, style: join)
                    } else {
                        strokeGeom = Polygon(subpath.bezierPath).stroked(width: scaledWidth, alignment: .centered, style: join)
                    }
                } else {
                    strokeGeom = subpath.bezierPath.stroked(width: scaledWidth, alignment: .centered, style: join)
                }
                geometries.append(
                    strokeGeom
                        .withLineCapStyle(cap)
                        .withMiterLimit(stroke.miterLimit)
                )
            }
        }

        guard !geometries.isEmpty else { return nil }
        return geometries.count == 1 ? geometries[0] : Union(geometries)
    }

    func makeText(info: SVGTextInfo) -> (any Geometry2D)? {
        guard !info.content.isEmpty else { return nil }

        let alignment: HorizontalTextAlignment = switch info.anchor {
        case .start: .left
        case .middle: .center
        case .end: .right
        }

        return Text(info.content)
            .withFont(info.fontName, size: info.fontSize * scale)
            .withTextAlignment(horizontal: alignment)
            .flipped(along: .y)
            .translated(x: info.position.x * scale, y: info.position.y * scale)
    }

    func finalizeDocument(shapes: [any Geometry2D], size: (width: Double, height: Double)) -> any Geometry2D {
        guard !shapes.isEmpty else { return Empty() }
        let content: any Geometry2D = shapes.count == 1 ? shapes[0] : Union(shapes)

        switch origin {
        case .bottomLeft:
            // Flip Y axis: SVG uses Y-down, Cadova uses Y-up
            return content
                .flipped(along: .y)
                .translated(y: size.height * scale)
        case .topLeft:
            return content
        }
    }
}

// MARK: - SVG Path Builder

private struct GeometrySVGPathBuilder: SVGPathBuilder {
    let scale: Double
    private var subpaths: [GeometrySVGConsumer.Subpath] = []
    private var currentPath: BezierPath2D?

    init(scale: Double) {
        self.scale = scale
    }

    mutating func move(to point: Vector2D) {
        finishCurrentSubpath(closed: false)
        currentPath = BezierPath2D(startPoint: point)
    }

    mutating func line(to point: Vector2D) {
        guard let path = currentPath else { return }
        currentPath = path.addingLine(to: point)
    }

    mutating func cubic(to end: Vector2D, control1: Vector2D, control2: Vector2D) {
        guard let path = currentPath else { return }
        currentPath = path.addingCubicCurve(controlPoint1: control1, controlPoint2: control2, end: end)
    }

    mutating func close() {
        if let path = currentPath {
            subpaths.append(.init(bezierPath: path.closed(), isClosed: true))
            currentPath = nil
        }
    }

    private mutating func finishCurrentSubpath(closed: Bool) {
        if let path = currentPath {
            subpaths.append(.init(bezierPath: path, isClosed: closed))
            currentPath = nil
        }
    }

    func build() -> [GeometrySVGConsumer.Subpath] {
        var result = subpaths
        if let path = currentPath {
            result.append(.init(bezierPath: path, isClosed: false))
        }
        return result
    }
}
