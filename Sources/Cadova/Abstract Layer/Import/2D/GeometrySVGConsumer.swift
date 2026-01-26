import Foundation
internal import Pelagos

/// A Pelagos renderer that extracts shapes as Cadova geometry instead of drawing.
internal final class ShapeExtractionRenderer: SVGRenderer {
    typealias Path = ExtractedPath
    typealias NativeColor = ResolvedColor

    let segmentation: Segmentation
    let scale: Double

    private var shapes: [any Geometry2D] = []
    private var stateStack: [RendererState] = []
    private var currentState = RendererState()

    /// Pixels per millimeter according to the SVG/CSS standard (96 pixels per inch).
    private static let pixelsPerMillimeter = 96.0 / 25.4

    init(segmentation: Segmentation, scale: Import<D2>.SVGScale) {
        self.segmentation = segmentation
        self.scale = switch scale {
        case .physical: 1.0 / Self.pixelsPerMillimeter
        case .pixels: 1.0
        }
    }

    // MARK: - State

    private struct RendererState {
        var transform: Pelagos.AffineTransform = .identity
        var clipPath: ExtractedPath?
        var opacity: Double = 1
    }

    // MARK: - Path Type

    struct ExtractedPath {
        var subpaths: [Subpath] = []
        var currentSubpath: Subpath?

        struct Subpath {
            var bezierPath: BezierPath2D
            var isClosed: Bool
        }

        mutating func finishCurrentSubpath(closed: Bool) {
            if let subpath = currentSubpath {
                var finished = subpath
                finished.isClosed = closed
                if closed {
                    finished.bezierPath = finished.bezierPath.closed()
                }
                subpaths.append(finished)
                currentSubpath = nil
            }
        }
    }

    // MARK: - SVGRenderer Protocol

    func makePath() -> ExtractedPath {
        ExtractedPath()
    }

    func moveTo(_ path: inout ExtractedPath, x: Double, y: Double) {
        path.finishCurrentSubpath(closed: false)
        let point = transformPoint(x: x, y: y)
        path.currentSubpath = .init(bezierPath: BezierPath2D(startPoint: point), isClosed: false)
    }

    func lineTo(_ path: inout ExtractedPath, x: Double, y: Double) {
        guard var subpath = path.currentSubpath else { return }
        let point = transformPoint(x: x, y: y)
        subpath.bezierPath = subpath.bezierPath.addingLine(to: point)
        path.currentSubpath = subpath
    }

    func curveTo(_ path: inout ExtractedPath, cp1x: Double, cp1y: Double, cp2x: Double, cp2y: Double, x: Double, y: Double) {
        guard var subpath = path.currentSubpath else { return }
        let cp1 = transformPoint(x: cp1x, y: cp1y)
        let cp2 = transformPoint(x: cp2x, y: cp2y)
        let end = transformPoint(x: x, y: y)
        subpath.bezierPath = subpath.bezierPath.addingCubicCurve(controlPoint1: cp1, controlPoint2: cp2, end: end)
        path.currentSubpath = subpath
    }

    func quadTo(_ path: inout ExtractedPath, cpx: Double, cpy: Double, x: Double, y: Double) {
        guard var subpath = path.currentSubpath else { return }
        let cp = transformPoint(x: cpx, y: cpy)
        let end = transformPoint(x: x, y: y)
        subpath.bezierPath = subpath.bezierPath.addingQuadraticCurve(controlPoint: cp, end: end)
        path.currentSubpath = subpath
    }

    func closePath(_ path: inout ExtractedPath) {
        path.finishCurrentSubpath(closed: true)
    }

    func makeColor(from resolved: ResolvedColor) -> ResolvedColor {
        resolved
    }

    func fill(_ path: ExtractedPath, color: ResolvedColor, rule: Pelagos.FillRule) {
        var finishedPath = path
        finishedPath.finishCurrentSubpath(closed: false)

        let fillRule = FillRule(from: rule)
        var polygons: [SimplePolygon] = []

        for subpath in finishedPath.subpaths where subpath.isClosed {
            let points = subpath.bezierPath.points(segmentation: segmentation)
            if points.count >= 3 {
                polygons.append(SimplePolygon(points))
            }
        }

        if !polygons.isEmpty {
            let node = GeometryNode<D2>(.shape2D(.polygons(SimplePolygonList(polygons), fillRule: fillRule)))
            shapes.append(NodeBasedGeometry(node))
        }
    }

    func stroke(_ path: ExtractedPath, color: ResolvedColor, style: StrokeStyle) {
        var finishedPath = path
        finishedPath.finishCurrentSubpath(closed: false)

        let join = LineJoinStyle(from: style.join)
        let cap = LineCapStyle(from: style.cap)
        let scaledWidth = style.width * scale

        for subpath in finishedPath.subpaths {
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
            shapes.append(
                strokeGeom
                    .withLineCapStyle(cap)
                    .withMiterLimit(style.miterLimit)
            )
        }
    }

    func strokeGradient(_ path: ExtractedPath, gradient: ResolvedGradient, style: StrokeStyle) {
        // Gradients are rendered as solid strokes (color information is lost)
        stroke(path, color: .black, style: style)
    }

    func fillGradient(_ path: ExtractedPath, gradient: ResolvedGradient, rule: Pelagos.FillRule) {
        // Gradients are rendered as solid fills (color information is lost)
        fill(path, color: .black, rule: rule)
    }

    func fillPattern(_ path: ExtractedPath, pattern: ResolvedPattern, rule: Pelagos.FillRule) {
        // Patterns are rendered as solid fills
        fill(path, color: .black, rule: rule)
    }

    func drawText(_ text: ResolvedTextContent) {
        guard let firstRun = text.runs.first, !firstRun.text.isEmpty else { return }

        // Combine all runs into a single string
        let content = text.runs.map(\.text).joined()

        let alignment: HorizontalTextAlignment = switch text.anchor {
        case .start: .left
        case .middle: .center
        case .end: .right
        }

        let position = transformPoint(x: text.x, y: text.y)
        let fontSize = firstRun.fontSize * scale

        let textGeom = Text(content)
            .withFont(firstRun.fontFamily ?? "Helvetica", size: fontSize)
            .withTextAlignment(horizontal: alignment)
            .flipped(along: .y)
            .translated(x: position.x, y: position.y)

        shapes.append(textGeom)
    }

    func drawImage(_ image: ResolvedImageContent) {}

    func save() {
        stateStack.append(currentState)
    }

    func restore() {
        if let state = stateStack.popLast() {
            currentState = state
        }
    }

    func concatenate(_ transform: Pelagos.AffineTransform) {
        currentState.transform = currentState.transform.concatenating(transform)
    }

    func clip(_ path: ExtractedPath, rule: Pelagos.FillRule) {
        // Clipping is not directly supported, but we store it for potential use
        var finishedPath = path
        finishedPath.finishCurrentSubpath(closed: false)
        currentState.clipPath = finishedPath
    }

    func setOpacity(_ opacity: Double) {
        currentState.opacity = opacity
    }

    // MARK: - Helpers

    private func transformPoint(x: Double, y: Double) -> Vector2D {
        let t = currentState.transform
        let tx = t.a * x + t.c * y + t.tx
        let ty = t.b * x + t.d * y + t.ty
        return Vector2D(x: tx * scale, y: ty * scale)
    }

    // MARK: - Result

    var output: any Geometry2D {
        Union(shapes)
    }
}

// MARK: - Enum Conversions

internal extension FillRule {
    init(from pelagosRule: Pelagos.FillRule) {
        switch pelagosRule {
        case .nonzero:
            self = .nonZero
        case .evenodd:
            self = .evenOdd
        }
    }
}

internal extension LineJoinStyle {
    init(from pelagosJoin: Pelagos.LineJoin) {
        switch pelagosJoin {
        case .miter, .miterClip, .arcs:
            self = .miter
        case .round:
            self = .round
        case .bevel:
            self = .bevel
        }
    }
}

internal extension LineCapStyle {
    init(from pelagosCap: Pelagos.LineCap) {
        switch pelagosCap {
        case .butt:
            self = .butt
        case .round:
            self = .round
        case .square:
            self = .square
        }
    }
}
