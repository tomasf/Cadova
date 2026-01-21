import Foundation
internal import SwiftDraw

/// Imports 2D geometry from an SVG file.
///
/// The SVG is parsed using SwiftDraw and converted into filled polygons, stroked outlines, and text.
/// Unsupported SVG features such as filters and masks are ignored.
public struct SVGImport: Shape2D {
    private let url: URL
    private let unitMode: UnitMode

    /// Controls how SVG units are interpreted when importing.
    public enum UnitMode: Hashable, Sendable, Codable {
        /// Physical units are preserved: 1mm in SVG becomes 1mm in output.
        /// Unitless values (pixels) are converted using the SVG standard of 96 pixels per inch.
        case physical

        /// Unitless values map directly: 1 pixel in SVG becomes 1mm in output.
        /// Physical units are scaled accordingly (e.g., 1mm in SVG becomes ~3.78mm).
        case pixels
    }

    /// Creates a new SVG import from a file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to the SVG document.
    ///   - unitMode: How to interpret SVG units. Defaults to `.physical`.
    public init(svg url: URL, unitMode: UnitMode = .physical) {
        self.url = url
        self.unitMode = unitMode
    }

    /// Creates a new SVG import from a file path.
    ///
    /// - Parameters:
    ///   - path: A file path to the SVG document. Can be relative or absolute.
    ///   - unitMode: How to interpret SVG units. Defaults to `.physical`.
    public init(svg path: String, unitMode: UnitMode = .physical) {
        self.init(svg: URL(expandingFilePath: path, extension: nil, relativeTo: nil), unitMode: unitMode)
    }

    public enum Error: Swift.Error {
        case invalidSVG
    }

    public var body: any Geometry2D {
        readEnvironment(\.scaledSegmentation) { segmentation in
            CachedNode(name: "import-svg", parameters: url, unitMode, segmentation) {
                let consumer = CadovaSVGConsumer(segmentation: segmentation, unitMode: unitMode)
                do {
                    return try SVG.extractShapes(from: url, using: consumer)
                } catch {
                    throw Error.invalidSVG
                }
            }
        }
    }
}

// MARK: - Consumer Implementation

/// Cadova's consumer that produces Geometry2D directly.
private struct CadovaSVGConsumer: SVGShapeConsumer {
    let segmentation: Segmentation
    let scale: Double

    /// Pixels per millimeter according to the SVG/CSS standard (96 pixels per inch).
    private static let pixelsPerMillimeter = 96.0 / 25.4

    init(segmentation: Segmentation, unitMode: SVGImport.UnitMode) {
        self.segmentation = segmentation
        self.scale = switch unitMode {
        case .physical:
            1.0 / Self.pixelsPerMillimeter
        case .pixels:
            1.0
        }
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

        // Build fill geometry (ignore paint color/gradient - Cadova only needs shape)
        if let fill = fill, fill.paint != .none {
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

        // Build stroke geometry (ignore paint color/gradient - Cadova only needs shape)
        if let stroke = stroke, stroke.paint != .none, stroke.width > 0 {
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
            .scaled(x: 1, y: -1)
            .translated(x: info.position.x * scale, y: info.position.y * scale)
    }

    func finalizeDocument(shapes: [any Geometry2D], size: (width: Double, height: Double)) -> any Geometry2D {
        guard !shapes.isEmpty else { return Empty() }
        return shapes.count == 1 ? shapes[0] : Union(shapes)
    }
}

// MARK: - Path Builder

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
