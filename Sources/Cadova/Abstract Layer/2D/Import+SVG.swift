import Foundation
internal import SwiftDraw

// MARK: - 2D (SVG) Support

extension Import where D == D2 {
    /// Creates a new SVG import from a file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to the SVG document.
    ///   - unitMode: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.bottomLeft`.
    public init(svg url: URL, unitMode: UnitMode = .physical, origin: Origin = .bottomLeft) {
        self.init {
            readEnvironment(\.scaledSegmentation) { segmentation in
                CachedNode(name: "import-svg", parameters: url, unitMode, origin, segmentation) {
                    let consumer = CadovaSVGConsumer(segmentation: segmentation, unitMode: unitMode, origin: origin)
                    do {
                        return try SVG.extractShapes(from: url, using: consumer)
                    } catch {
                        throw SVGError.invalidSVG
                    }
                }
            }
        }
    }

    /// Creates a new SVG import from a file path.
    ///
    /// - Parameters:
    ///   - path: A file path to the SVG document. Can be relative or absolute.
    ///   - unitMode: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.bottomLeft`.
    public init(svg path: String, unitMode: UnitMode = .physical, origin: Origin = .bottomLeft) {
        self.init(svg: URL(expandingFilePath: path, extension: nil, relativeTo: nil), unitMode: unitMode, origin: origin)
    }

    /// Controls how SVG units are interpreted when importing.
    public enum UnitMode: Hashable, Sendable, Codable {
        /// Physical units are preserved: 1mm in SVG becomes 1mm in output.
        /// Unitless values (pixels) are converted using the SVG standard of 96 pixels per inch.
        case physical

        /// Unitless values map directly: 1 pixel in SVG becomes 1mm in output.
        /// Physical units are scaled accordingly (e.g., 1mm in SVG becomes ~3.78mm).
        case pixels
    }

    /// Controls how the SVG coordinate system is mapped to Cadova's coordinate system.
    public enum Origin: Hashable, Sendable, Codable {
        /// Aligns the SVG's bottom-left corner with the origin and flips the Y axis.
        /// The SVG appears the same way it does in browsers/editors.
        case bottomLeft

        /// Keeps the SVG's top-left origin aligned with Cadova's origin.
        /// Y coordinates are preserved but content appears upside-down compared to browsers.
        case topLeft
    }

    /// Errors that can occur when importing an SVG.
    public enum SVGError: Swift.Error {
        case invalidSVG
    }
}

// MARK: - SVG Consumer Implementation

/// Cadova's consumer that produces Geometry2D directly.
private struct CadovaSVGConsumer: SVGShapeConsumer {
    let segmentation: Segmentation
    let scale: Double
    let origin: Import<D2>.Origin

    /// Pixels per millimeter according to the SVG/CSS standard (96 pixels per inch).
    private static let pixelsPerMillimeter = 96.0 / 25.4

    init(segmentation: Segmentation, unitMode: Import<D2>.UnitMode, origin: Import<D2>.Origin) {
        self.segmentation = segmentation
        self.scale = switch unitMode {
        case .physical:
            1.0 / Self.pixelsPerMillimeter
        case .pixels:
            1.0
        }
        self.origin = origin
    }

    typealias Point = Vector2D
    typealias Path = [Subpath]
    typealias Shape = any Geometry2D

    struct Subpath {
        let bezierPath: BezierPath2D
        let isClosed: Bool
    }

    func makePoint(x: Double, y: Double) -> Vector2D {
        Vector2D(x: x * scale, y: y * scale)
    }

    func makePathBuilder() -> any SVGPathBuilder<Vector2D, [Subpath]> {
        CadovaPathBuilder(scale: scale)
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

        // Text is always flipped so it's readable in Cadova's Y-up coordinate system
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

private struct CadovaPathBuilder: SVGPathBuilder {
    let scale: Double
    private var subpaths: [CadovaSVGConsumer.Subpath] = []
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

    func build() -> [CadovaSVGConsumer.Subpath] {
        var result = subpaths
        if let path = currentPath {
            result.append(.init(bezierPath: path, isClosed: false))
        }
        return result
    }
}

// MARK: - Enum Conversions

private extension FillRule {
    init(from svgRule: SVGFillRule) {
        switch svgRule {
        case .nonZero:
            self = .nonZero
        case .evenOdd:
            self = .evenOdd
        }
    }
}

private extension LineJoinStyle {
    init(from svgJoin: SVGLineJoin) {
        switch svgJoin {
        case .miter:
            self = .miter
        case .round:
            self = .round
        case .bevel:
            self = .bevel
        }
    }
}

private extension LineCapStyle {
    init(from svgCap: SVGLineCap) {
        switch svgCap {
        case .butt:
            self = .butt
        case .round:
            self = .round
        case .square:
            self = .square
        }
    }
}
