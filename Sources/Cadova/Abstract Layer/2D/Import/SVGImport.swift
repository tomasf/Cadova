import Foundation
import SwiftDraw

/// Imports 2D geometry from an SVG file.
///
/// The SVG is parsed using SwiftDraw and converted into filled polygons and stroked outlines.
/// Unsupported SVG features such as filters, masks, and text are ignored.
public struct SVGImport: Shape2D {
    private let url: URL

    /// Creates a new SVG import from a file URL.
    ///
    /// - Parameter url: The file URL to the SVG document.
    public init(svg url: URL) {
        self.url = url
    }

    /// Creates a new SVG import from a file path.
    ///
    /// - Parameter path: A file path to the SVG document. Can be relative or absolute.
    public init(svg path: String) {
        self.init(svg: URL(expandingFilePath: path, extension: nil, relativeTo: nil))
    }

    public enum Error: Swift.Error {
        case invalidSVG
    }

    public var body: any Geometry2D {
        readEnvironment(\.scaledSegmentation) { segmentation in
            CachedNode(name: "import-svg", parameters: url, segmentation) {
                guard let document = SVGDocument(fileURL: url) else {
                    throw Error.invalidSVG
                }

                return SVGDocumentConverter(document: document, segmentation: segmentation).geometry
            }
        }
    }
}

private struct SVGDocumentConverter {
    let document: SVGDocument
    let segmentation: Segmentation

    var geometry: any Geometry2D {
        var fillGeometries: [any Geometry2D] = []
        var strokeGeometries: [any Geometry2D] = []

        for shape in document.shapes {
            let subpaths = Self.subpaths(from: shape.path, segmentation: segmentation)

            if shape.hasFill {
                let fillRule = Self.fillRule(from: shape.fillRule)
                var shapePolygons: [SimplePolygon] = []
                for subpath in subpaths {
                    guard subpath.isClosed, let points = subpath.points else { continue }
                    shapePolygons.append(SimplePolygon(points))
                }

                if !shapePolygons.isEmpty {
                    let polygonList = SimplePolygonList(shapePolygons)
                    let node = GeometryNode<D2>(.shape2D(.polygons(polygonList, fillRule: fillRule)))
                    fillGeometries.append(NodeBasedGeometry(node))
                }
            }

            if let stroke = shape.stroke, stroke.width > 0 {
                let join = Self.lineJoin(from: stroke.lineJoin)
                let cap = Self.lineCap(from: stroke.lineCap)
                for subpath in subpaths {
                    let strokeGeometry: any Geometry2D
                    if subpath.isClosed {
                        if let points = subpath.points {
                            strokeGeometry = Polygon(points).stroked(width: stroke.width, alignment: .centered, style: join)
                        } else {
                            strokeGeometry = Polygon(subpath.path).stroked(width: stroke.width, alignment: .centered, style: join)
                        }
                    } else {
                        strokeGeometry = subpath.path.stroked(width: stroke.width, alignment: .centered, style: join)
                    }

                    strokeGeometries.append(
                        strokeGeometry
                            .withLineCapStyle(cap)
                            .withMiterLimit(stroke.miterLimit)
                    )
                }
            }
        }

        var geometries: [any Geometry2D] = []
        if !fillGeometries.isEmpty {
            let fills = fillGeometries.count == 1 ? fillGeometries[0] : Union(fillGeometries)
            geometries.append(fills)
        }

        if !strokeGeometries.isEmpty {
            let strokes = strokeGeometries.count == 1 ? strokeGeometries[0] : Union(strokeGeometries)
            geometries.append(strokes)
        }

        guard !geometries.isEmpty else { return Empty() }
        return geometries.count == 1 ? geometries[0] : Union(geometries)
    }

    private static func subpaths(from path: SVGDocument.Path, segmentation: Segmentation) -> [SVGSubpath] {
        var results: [SVGSubpath] = []
        var currentPath: BezierPath2D?

        for segment in path.segments {
            switch segment {
            case let .move(to: point):
                if let path = currentPath {
                    results.append(.init(path: path, isClosed: false, segmentation: segmentation))
                }
                currentPath = BezierPath2D(startPoint: vector(from: point))

            case let .line(to: point):
                guard let path = currentPath else { continue }
                currentPath = path.addingLine(to: vector(from: point))

            case let .cubic(to: point, control1: control1, control2: control2):
                guard let path = currentPath else { continue }
                currentPath = path.addingCubicCurve(
                    controlPoint1: vector(from: control1),
                    controlPoint2: vector(from: control2),
                    end: vector(from: point)
                )

            case .close:
                guard let path = currentPath else { continue }
                results.append(.init(path: path.closed(), isClosed: true, segmentation: segmentation))
                currentPath = nil
            }
        }

        if let path = currentPath {
            results.append(.init(path: path, isClosed: false, segmentation: segmentation))
        }

        return results
    }

    private static func vector(from point: SVGDocument.Point) -> Vector2D {
        .init(x: point.x, y: point.y)
    }

    private static func fillRule(from rule: SVGDocument.FillRule) -> FillRule {
        switch rule {
        case .nonZero:
            return .nonZero
        case .evenOdd:
            return .evenOdd
        }
    }

    private static func lineJoin(from join: SVGDocument.LineJoin) -> LineJoinStyle {
        switch join {
        case .miter:
            return .miter
        case .round:
            return .round
        case .bevel:
            return .bevel
        }
    }

    private static func lineCap(from cap: SVGDocument.LineCap) -> LineCapStyle {
        switch cap {
        case .butt:
            return .butt
        case .round:
            return .round
        case .square:
            return .square
        }
    }

}

private struct SVGSubpath {
    let path: BezierPath2D
    let isClosed: Bool
    let points: [Vector2D]?

    init(path: BezierPath2D, isClosed: Bool, segmentation: Segmentation) {
        self.path = path
        self.isClosed = isClosed
        self.points = isClosed ? path.points(segmentation: segmentation) : nil
    }
}
