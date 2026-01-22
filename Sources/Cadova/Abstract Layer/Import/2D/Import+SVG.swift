import Foundation
internal import SwiftDraw

// MARK: - 2D (SVG) Support

extension Import where D == D2 {
    /// Creates a new SVG import from a file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL to the SVG document.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.bottomLeft`.
    public init(svg url: URL, scale: SVGScale = .physical, origin: SVGOrigin = .bottomLeft) {
        self.init {
            readEnvironment(\.scaledSegmentation) { segmentation in
                CachedNode(name: "import-svg", parameters: url, scale, origin, segmentation) {
                    try SVG.extractShapes(from: url, using: GeometrySVGConsumer(segmentation: segmentation, scale: scale, origin: origin))
                }
            }
        }
    }

    /// Creates a new SVG import from a file path.
    ///
    /// - Parameters:
    ///   - path: A file path to the SVG document. Can be relative or absolute.
    ///   - scale: How to interpret SVG units. Defaults to `.physical`.
    ///   - origin: How to map the SVG coordinate system. Defaults to `.bottomLeft`.
    public init(svg path: String, scale: SVGScale = .physical, origin: SVGOrigin = .bottomLeft) {
        self.init(svg: URL(expandingFilePath: path), scale: scale, origin: origin)
    }

    /// Controls how SVG units are interpreted when importing.
    public enum SVGScale: Hashable, Sendable, Codable {
        /// Physical units are preserved: 1mm in SVG becomes 1mm in output.
        /// Unitless values (pixels) are converted using the SVG standard of 96 pixels per inch.
        case physical

        /// Unitless values map directly: 1 pixel in SVG becomes 1mm in output.
        /// Physical units are scaled accordingly (e.g., 1mm in SVG becomes ~3.78mm).
        case pixels
    }

    /// Controls how the SVG coordinate system is mapped to Cadova's coordinate system.
    public enum SVGOrigin: Hashable, Sendable, Codable {
        /// Aligns the SVG's bottom-left corner with the origin and flips the Y axis.
        /// The SVG appears the same way it does in browsers/editors.
        case bottomLeft

        /// Keeps the SVG's top-left origin aligned with Cadova's origin.
        /// Y coordinates are preserved but content appears upside-down compared to browsers.
        case topLeft
    }
}

// MARK: - Enum Conversions

internal extension FillRule {
    init(from svgRule: SVGFillRule) {
        switch svgRule {
        case .nonZero:
            self = .nonZero
        case .evenOdd:
            self = .evenOdd
        }
    }
}

internal extension LineJoinStyle {
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

internal extension LineCapStyle {
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
